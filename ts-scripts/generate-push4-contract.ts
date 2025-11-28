import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { execSync, spawn } from "child_process";
import { getFunctionSelector, generateRandomPrefix } from "./utils";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const IMAGE_DATA_FILE = path.join(__dirname, "./data/pixel-data.json");
const OUTPUT_FILE = path.join(__dirname, "../src/PUSH4.sol");
const PROGRESS_FILE = path.join(__dirname, "./data/selector-mining-progress.json");
const SELECTORS_DB_FILE = path.join(__dirname, "./data/mined-selectors-db.json");
const MINER_DIR = path.join(__dirname, "../function-selector-miner-cuda");

// Types
interface ImageData {
  width: number;
  height: number;
  pixels: string[];
}

interface FunctionData {
  index: number;
  selector: string;
  funcName: string;
  signature: string;
  params: string;
  hasParam: boolean;
  seed: string;
  prefix: string;
}

interface MiningResult {
  signature: string;
  funcName: string;
  params: string;
  hasParam: boolean;
  seed: string;
  prefix: string;
  nonce?: string;
}

interface ProgressData {
  timestamp: string;
  selectorsData: string[];
  completed: number;
  total: number;
  functions: FunctionData[];
}

interface SelectorsDatabase {
  timestamp: string;
  totalSelectors: number;
  selectors: Record<string, StoredSelectorData>;
}

interface StoredSelectorData {
  funcName: string;
  signature: string;
  params: string;
  hasParam: boolean;
  seed: string;
  prefix: string;
  minedAt: string;
}

interface MetadataOutput {
  width: number;
  height: number;
  pixels: string[];
  selectors: string[];
  functions: FunctionData[];
}

// Miner setup
function setupMiner(): string {
  const minerBinary = path.join(MINER_DIR, "selector_miner_cuda");

  if (!fs.existsSync(minerBinary)) {
    console.log("Building CUDA GPU miner...");
    console.log("This requires CUDA toolkit installed.");

    try {
      execSync("nvcc --version", { stdio: "ignore" });
    } catch (error) {
      throw new Error("CUDA compiler (nvcc) not found. Please install CUDA toolkit.");
    }

    execSync("make", { cwd: MINER_DIR, stdio: "inherit" });

    if (!fs.existsSync(minerBinary)) {
      throw new Error("Failed to build CUDA miner");
    }
  }

  return minerBinary;
}

// Mining functions
function findMatchingSignature(
  minerBinary: string,
  targetSelector: Buffer,
  index: number,
  existingFunctionNames: Set<string>,
  alreadyTriedForThisSelector: Set<string> = new Set(),
): MiningResult {
  const targetHex = "0x" + targetSelector.toString("hex");
  const workingDir = path.dirname(minerBinary);
  let attempt = 0;
  const maxAttempts = 30;

  while (attempt < maxAttempts) {
    try {
      const prefix = generateRandomPrefix(attempt);

      if (alreadyTriedForThisSelector.has(prefix)) {
        attempt++;
        continue;
      }
      alreadyTriedForThisSelector.add(prefix);

      if (attempt > 0) {
        console.log(`  WARNING: Duplicate found, retrying with prefix "${prefix}"...`);
      } else {
        console.log(`  Mining selector ${targetHex}...`);
      }

      const startTime = Date.now();
      const cmd = `${minerBinary} "${prefix}" "()" ${targetHex} 2>&1 | grep -E "(Function found|Error|CUDA error)"`;

      const output = execSync(cmd, {
        cwd: workingDir,
        timeout: 300000,
        encoding: "utf8",
        maxBuffer: 10 * 1024 * 1024,
        shell: "/bin/bash",
      });

      const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
      const match = output.match(/Function found:\s*([a-zA-Z_]\w*)\(/);

      if (match) {
        let funcName = match[1];

        if (/^\d+$/.test(funcName)) {
          funcName = `${prefix}${funcName}`;
        }

        const seed = funcName.replace(/^[a-zA-Z_]+/, "");
        const signature = `${funcName}()`;
        const selector = getFunctionSelector(signature);

        if (selector.equals(targetSelector)) {
          if (existingFunctionNames.has(funcName)) {
            console.log(`  WARNING: Duplicate function name "${funcName}" detected`);
            attempt++;
            continue;
          }

          const prefixInfo = prefix === "f" ? "" : ` (prefix: ${prefix})`;
          console.log(`  Found: ${signature} (${elapsed}s)${prefixInfo}`);
          return {
            signature,
            funcName,
            params: "",
            hasParam: false,
            seed,
            prefix,
          };
        } else {
          console.error(`  ERROR: Selector mismatch! Expected ${targetHex}, got 0x${selector.toString("hex")}`);
          console.error(`  ERROR: Output: ${output}`);
        }
      }

      console.error(`  ERROR: Could not parse miner output: ${output.substring(0, 500)}`);
      throw new Error("Miner output did not contain valid function signature");
    } catch (error) {
      const err = error as NodeJS.ErrnoException;
      if (err.code === "ETIMEDOUT") {
        console.error(`  ERROR: Timeout after 5 minutes`);
      }
      if (err.message !== "Miner output did not contain valid function signature") {
        console.error(`  ERROR: Failed to mine selector ${targetHex}:`, err.message);
      }
      attempt++;
      continue;
    }
  }

  throw new Error(`Could not find unique function name after ${maxAttempts} attempts with different prefixes`);
}

async function batchMineSelectors(
  minerBinary: string,
  selectorsToMine: number[],
  selectorsData: Buffer[],
): Promise<Map<number, MiningResult>> {
  const workingDir = path.dirname(minerBinary);
  const tempSelectorsFile = path.join(workingDir, "temp_selectors.txt");

  return new Promise((resolve, reject) => {
    try {
      const selectorLines = selectorsToMine.map((idx) => "0x" + selectorsData[idx].toString("hex")).join("\n");
      fs.writeFileSync(tempSelectorsFile, selectorLines);

      console.log(`Starting batch mining for ${selectorsToMine.length} selectors...`);

      const startTime = Date.now();
      const minerProcess = spawn(minerBinary, ["--batch", tempSelectorsFile], { cwd: workingDir });

      let outputBuffer = "";
      let inResultsSection = false;
      const resultsLines: string[] = [];

      minerProcess.stdout.on("data", (data: Buffer) => {
        const text = data.toString();
        outputBuffer += text;

        const lines = text.split("\n");
        for (const line of lines) {
          if (line.trim()) {
            if (line.includes("=== RESULTS ===")) {
              inResultsSection = true;
              continue;
            }
            if (line.includes("=== END RESULTS ===")) {
              inResultsSection = false;
              continue;
            }

            if (inResultsSection) {
              resultsLines.push(line.trim());
            } else {
              console.log(line);
            }
          }
        }
      });

      minerProcess.stderr.on("data", (data: Buffer) => {
        const text = data.toString();
        if (text.trim()) {
          console.error(text.trim());
        }
      });

      minerProcess.on("close", (code) => {
        if (fs.existsSync(tempSelectorsFile)) {
          fs.unlinkSync(tempSelectorsFile);
        }

        if (code !== 0) {
          reject(new Error(`Miner process exited with code ${code}`));
          return;
        }

        try {
          const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
          const results = new Map<string, MiningResult>();

          for (const line of resultsLines) {
            if (!line) continue;

            const parts = line.split("|");
            if (parts.length !== 3) {
              console.warn(`Warning: Could not parse result line: ${line}`);
              continue;
            }

            const [selectorHex, signature, nonce] = parts;
            const funcName = signature.replace(/\(\)$/, "");
            const seed = funcName.replace(/^f/, "");

            results.set(selectorHex, {
              signature,
              funcName,
              params: "",
              hasParam: false,
              seed,
              prefix: "f",
              nonce,
            });
          }

          console.log(
            `\nBatch mining complete! Found ${results.size}/${selectorsToMine.length} selectors in ${elapsed}s`,
          );

          const indexedResults = new Map<number, MiningResult>();
          for (const idx of selectorsToMine) {
            const selectorHex = "0x" + selectorsData[idx].toString("hex");
            const result = results.get(selectorHex);
            if (result) {
              indexedResults.set(idx, result);
            }
          }

          resolve(indexedResults);
        } catch (error) {
          reject(error);
        }
      });

      minerProcess.on("error", (error) => {
        if (fs.existsSync(tempSelectorsFile)) {
          fs.unlinkSync(tempSelectorsFile);
        }
        reject(error);
      });
    } catch (error) {
      if (fs.existsSync(tempSelectorsFile)) {
        fs.unlinkSync(tempSelectorsFile);
      }
      reject(error);
    }
  });
}

// Progress and database functions
function saveProgress(selectorsData: Buffer[], functions: FunctionData[]): void {
  const progress: ProgressData = {
    timestamp: new Date().toISOString(),
    selectorsData: selectorsData.map((s) => s.toString("hex")),
    completed: functions.length,
    total: selectorsData.length,
    functions,
  };

  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
}

function loadProgress(): ProgressData | null {
  if (fs.existsSync(PROGRESS_FILE)) {
    try {
      const progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, "utf8")) as ProgressData;
      console.log(`\nFound existing progress: ${progress.completed}/${progress.total} selectors`);
      console.log(`   Last updated: ${progress.timestamp}`);
      return progress;
    } catch (error) {
      const err = error as Error;
      console.warn("WARNING: Could not load progress file:", err.message);
      return null;
    }
  }
  return null;
}

function loadSelectorsDatabase(): Record<string, StoredSelectorData> {
  if (fs.existsSync(SELECTORS_DB_FILE)) {
    try {
      const db = JSON.parse(fs.readFileSync(SELECTORS_DB_FILE, "utf8")) as SelectorsDatabase;
      console.log(`\nLoaded selectors database: ${Object.keys(db.selectors || {}).length} mined selectors`);
      console.log(`   Last updated: ${db.timestamp}`);
      return db.selectors || {};
    } catch (error) {
      const err = error as Error;
      console.warn("WARNING: Could not load selectors database:", err.message);
      return {};
    }
  }
  return {};
}

function saveToSelectorsDatabase(
  selectorsDb: Record<string, StoredSelectorData>,
  selectorHex: string,
  functionData: FunctionData,
): void {
  selectorsDb[selectorHex] = {
    funcName: functionData.funcName,
    signature: functionData.signature,
    params: functionData.params || "",
    hasParam: functionData.hasParam || false,
    seed: functionData.seed,
    prefix: functionData.prefix || "f",
    minedAt: new Date().toISOString(),
  };

  const dbData: SelectorsDatabase = {
    timestamp: new Date().toISOString(),
    totalSelectors: Object.keys(selectorsDb).length,
    selectors: selectorsDb,
  };

  fs.writeFileSync(SELECTORS_DB_FILE, JSON.stringify(dbData, null, 2));
}

// Contract generation
function generateContractCode(
  functions: FunctionData[],
  selectorsData: Buffer[],
  authorizedAddress: string = "0x00000063266aAAeDD489e4956153855626E44061",
): string {
  const functionCode = functions
    .map((func, idx) => {
      const selectorHex = "0x" + selectorsData[idx].toString("hex");
      return `    /* ${selectorHex} */
    function ${func.funcName}() external view returns (bytes4) {
        return _e(msg.sig);
    }`;
    })
    .join("\n\n");

  return `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract PUSH4 {
${functionCode}

    /* execute through proxy (if set) or return the original selector */
    function _e(bytes4 signature) internal view returns (bytes4) {
        address push4Core = ${authorizedAddress};

        bytes memory proxySelector = abi.encodeWithSignature("proxy()");
        bytes memory executeSelector = abi.encodeWithSignature("execute(bytes4)", signature);

        (bool success, bytes memory result) = push4Core.staticcall(proxySelector);
        if (!success) {
            return signature;
        }
        address proxy = abi.decode(result, (address));
        if (proxy == address(0)) {
            return signature;
        }

        (bool success2, bytes memory result2) = proxy.staticcall(executeSelector);
        if (!success2) {
            bytes memory h = "0123456789abcdef";
            bytes memory r = new bytes(10);
            r[0] = "0";
            r[1] = "x";
            for (uint256 i = 0; i < 4; i++) {
                r[2 + i * 2] = h[uint8(signature[i]) >> 4];
                r[3 + i * 2] = h[uint8(signature[i]) & 0xf];
            }
            revert(string(abi.encodePacked("Failed to call execute for selector: ", string(r))));
        }
        bytes4 returnValue = abi.decode(result2, (bytes4));

        return returnValue;
    }
}
`;
}

// Main function
async function generatePUSH4Contract(
  authorizedAddress: string = "0x00000063266aAAeDD489e4956153855626E44061",
): Promise<void> {
  console.log(`Using authorized address: ${authorizedAddress}`);

  console.log("Reading image pixel data...");
  const imageData = JSON.parse(fs.readFileSync(IMAGE_DATA_FILE, "utf8")) as ImageData;
  const { width, height, pixels } = imageData;

  console.log(`Image: ${width}x${height} pixels, 4 bytes per pixel`);
  console.log(`Total pixels/selectors: ${pixels.length}`);

  const selectorsData = pixels.map((pixel) => Buffer.from(pixel, "hex"));
  const selectorsDb = loadSelectorsDatabase();
  const existingProgress = loadProgress();
  const functions: (FunctionData | null)[] = [];
  const selectorMap = new Map<string, FunctionData>();

  // Load from persistent database
  for (const [selectorHex, funcData] of Object.entries(selectorsDb)) {
    selectorMap.set(selectorHex, {
      selector: selectorHex,
      funcName: funcData.funcName,
      signature: funcData.signature,
      params: funcData.params,
      hasParam: funcData.hasParam,
      seed: funcData.seed,
      prefix: funcData.prefix,
      index: 0, // Will be updated
    });
  }

  // Overlay with current progress
  if (existingProgress?.functions) {
    for (const func of existingProgress.functions) {
      selectorMap.set(func.selector, func);
    }
    console.log(
      `\nLoaded ${selectorMap.size} existing function mappings (${Object.keys(selectorsDb).length} from database)\n`,
    );
  } else if (Object.keys(selectorsDb).length > 0) {
    console.log(`\nLoaded ${selectorMap.size} function mappings from database\n`);
  }

  // Match selectors and identify which ones need mining
  let reusedCount = 0;
  const needMiningIndices: number[] = [];

  for (let i = 0; i < selectorsData.length; i++) {
    const targetHex = selectorsData[i].toString("hex");

    if (selectorMap.has(targetHex)) {
      const existingFunc = selectorMap.get(targetHex)!;
      functions.push({
        ...existingFunc,
        index: i,
      });
      reusedCount++;
    } else {
      needMiningIndices.push(i);
      functions.push(null);
    }
  }

  console.log(`Reused ${reusedCount} existing selectors`);
  console.log(`Need to mine ${needMiningIndices.length} new selectors\n`);

  if (needMiningIndices.length > 0) {
    console.log("Setting up CUDA GPU miner...");
    const minerBinary = setupMiner();
    console.log("GPU miner ready\n");

    const existingFunctionNames = new Set(
      functions.filter((f): f is FunctionData => f !== null).map((f) => f.funcName),
    );

    const useBatchMining = needMiningIndices.length >= 10;

    if (useBatchMining) {
      console.log("Mining function signatures using batch mode...");

      try {
        const batchResults = await batchMineSelectors(minerBinary, needMiningIndices, selectorsData);

        let successCount = 0;
        for (const i of needMiningIndices) {
          const result = batchResults.get(i);
          if (result) {
            const targetHex = selectorsData[i].toString("hex");
            const functionData: FunctionData = {
              index: i,
              selector: targetHex,
              funcName: result.funcName,
              signature: result.signature,
              params: result.params || "",
              hasParam: result.hasParam || false,
              seed: result.seed,
              prefix: result.prefix || "f",
            };

            functions[i] = functionData;
            existingFunctionNames.add(result.funcName);
            saveToSelectorsDatabase(selectorsDb, targetHex, functionData);
            successCount++;
          }
        }

        saveProgress(
          selectorsData,
          functions.filter((f): f is FunctionData => f !== null),
        );

        // Fall back to single mining for failed selectors
        const failedIndices = needMiningIndices.filter((i) => !batchResults.has(i));
        if (failedIndices.length > 0) {
          console.log(
            `\nWARNING: ${failedIndices.length} selectors not found in batch mode, falling back to single mining...\n`,
          );

          for (const i of failedIndices) {
            const targetSelector = selectorsData[i];
            const targetHex = targetSelector.toString("hex");

            console.log(`Mining selector ${i + 1}: 0x${targetHex}`);

            try {
              const result = findMatchingSignature(minerBinary, targetSelector, i, existingFunctionNames);

              const functionData: FunctionData = {
                index: i,
                selector: targetHex,
                funcName: result.funcName,
                signature: result.signature,
                params: result.params || "",
                hasParam: result.hasParam || false,
                seed: result.seed,
                prefix: result.prefix || "f",
              };

              functions[i] = functionData;
              existingFunctionNames.add(result.funcName);
              saveToSelectorsDatabase(selectorsDb, targetHex, functionData);
              console.log(`  Saved to database`);

              saveProgress(
                selectorsData,
                functions.filter((f): f is FunctionData => f !== null),
              );
            } catch (error) {
              const err = error as Error;
              console.error(`\nFATAL ERROR mining selector ${i + 1}:`, err.message);
              throw error;
            }
          }
        }
      } catch (error) {
        const err = error as Error;
        console.error(`\nFATAL ERROR in batch mining:`, err.message);
        console.log("Saving progress before exit...");
        saveProgress(
          selectorsData,
          functions.filter((f): f is FunctionData => f !== null),
        );
        throw error;
      }
    } else {
      // Single mode mining
      console.log("Mining function signatures for new selectors...");

      for (let idx = 0; idx < needMiningIndices.length; idx++) {
        const i = needMiningIndices[idx];
        const targetSelector = selectorsData[i];
        const targetHex = targetSelector.toString("hex");

        console.log(`[${idx + 1}/${needMiningIndices.length}] Mining selector ${i + 1}: 0x${targetHex}`);

        try {
          const result = findMatchingSignature(minerBinary, targetSelector, i, existingFunctionNames);

          const functionData: FunctionData = {
            index: i,
            selector: targetHex,
            funcName: result.funcName,
            signature: result.signature,
            params: result.params || "",
            hasParam: result.hasParam || false,
            seed: result.seed,
            prefix: result.prefix || "f",
          };

          functions[i] = functionData;
          existingFunctionNames.add(result.funcName);
          saveToSelectorsDatabase(selectorsDb, targetHex, functionData);
          console.log(`  Saved to database (total: ${Object.keys(selectorsDb).length} selectors)`);

          saveProgress(
            selectorsData,
            functions.filter((f): f is FunctionData => f !== null),
          );
        } catch (error) {
          const err = error as Error;
          console.error(`\nFATAL ERROR mining selector ${i + 1}:`, err.message);
          console.log("Saving progress before exit...");
          saveProgress(
            selectorsData,
            functions.filter((f): f is FunctionData => f !== null),
          );
          throw error;
        }
      }
    }
  } else {
    console.log("All selectors already exist! No mining needed.\n");
  }

  console.log("\nGenerating Solidity contract...");

  const completeFunctions = functions.filter((f): f is FunctionData => f !== null);
  const contract = generateContractCode(completeFunctions, selectorsData, authorizedAddress);

  // Backup existing contract if it exists
  if (fs.existsSync(OUTPUT_FILE)) {
    const backupFile = OUTPUT_FILE + ".backup";
    fs.renameSync(OUTPUT_FILE, backupFile);
    console.log(`Backed up existing contract to: ${backupFile}`);
  }

  fs.writeFileSync(OUTPUT_FILE, contract);

  console.log(`\nContract generated successfully: ${OUTPUT_FILE}`);
  console.log(`  Total functions: ${completeFunctions.length}`);
  console.log(`  Original data size: ${pixels.length * 4} bytes`);
  console.log(`  Image: ${width}x${height} pixels`);

  const metadata: MetadataOutput = {
    width,
    height,
    pixels,
    selectors: selectorsData.map((s) => "0x" + s.toString("hex")),
    functions: completeFunctions,
  };

  fs.writeFileSync(path.join(__dirname, "./data/selector-contract-metadata.json"), JSON.stringify(metadata, null, 2));
}

// Handle interruptions
process.on("SIGINT", () => {
  console.log("\n\nWARNING: Interrupted by user. Progress has been saved.");
  console.log("Run the script again to resume from where you left off.\n");
  process.exit(0);
});

// Run
try {
  const authorizedAddress = process.argv[2] || "0x00000063266aAAeDD489e4956153855626E44061";
  await generatePUSH4Contract(authorizedAddress);
  process.exit(0);
} catch (error) {
  if (error instanceof Error) {
    console.error("\nERROR:", error.message);
    console.error(error.stack);
  }
  console.log("\nProgress has been saved. Run the script again to resume.\n");
  process.exit(1);
}
