import { execSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SELECTOR_METADATA_FILE = path.join(__dirname, "./data/selector-mining-progress.json");
const SMART_CONTRACTS_DIR = path.join(__dirname, "..");

// Types
interface MetadataFile {
  timestamp: string;
  selectorsData: string[];
  completed: number;
  total: number;
  functions: Array<{
    index: number;
    selector: string;
    funcName: string;
    signature: string;
    params: string;
    hasParam: boolean;
    seed: string;
    prefix: string;
  }>;
}

interface ComparisonResult {
  falsePositives: string[];
  missing: string[];
  correct: string[];
}

// Extraction functions
function extractSelectorsFromTest(): string[] {
  console.log("Running forge test to extract selectors...\n");

  try {
    const output = execSync("forge test -vvv --match-test test_extractSelectorsFromBytecode", {
      encoding: "utf8",
      maxBuffer: 10 * 1024 * 1024,
      cwd: SMART_CONTRACTS_DIR,
    });

    const selectorRegex = /0x[0-9a-f]{8}/gi;
    const matches = output.match(selectorRegex);

    if (!matches) {
      console.log("No selectors found in test output");
      return [];
    }

    const uniqueSelectors = [...new Set(matches.map((s) => s.toLowerCase()))];
    uniqueSelectors.sort();

    console.log(`Found ${uniqueSelectors.length} unique selectors in test output\n`);

    return uniqueSelectors;
  } catch (error) {
    const err = error as Error;
    console.error("Error running forge test:");
    console.error(err.message);
    process.exit(1);
  }
}

function loadMinedSelectors(): { minedSelectors: string[]; metadata: MetadataFile } {
  console.log("Loading mined selectors from metadata...\n");

  if (!fs.existsSync(SELECTOR_METADATA_FILE)) {
    console.error(`Metadata file not found: ${SELECTOR_METADATA_FILE}`);
    process.exit(1);
  }

  const metadata = JSON.parse(fs.readFileSync(SELECTOR_METADATA_FILE, "utf8")) as MetadataFile;

  if (!metadata.selectorsData || !Array.isArray(metadata.selectorsData)) {
    console.error("Invalid metadata format: missing selectorsData array");
    process.exit(1);
  }

  const minedSelectors = metadata.selectorsData.map((s) => "0x" + s.toLowerCase()).sort();

  console.log(`Loaded ${minedSelectors.length} mined selectors\n`);

  return { minedSelectors, metadata };
}

// Comparison functions
function compareSelectors(testSelectors: string[], minedSelectors: string[]): ComparisonResult {
  console.log("Comparing selectors...\n");
  console.log("=".repeat(80));

  const falsePositives = testSelectors.filter((s) => !minedSelectors.includes(s));
  const missing = minedSelectors.filter((s) => !testSelectors.includes(s));
  const correct = testSelectors.filter((s) => minedSelectors.includes(s));

  console.log(`\nCOMPARISON RESULTS:`);
  console.log(`   Total in test output: ${testSelectors.length}`);
  console.log(`   Total mined:          ${minedSelectors.length}`);
  console.log(`   Correct matches:      ${correct.length}`);
  console.log(`   False positives:      ${falsePositives.length}`);
  console.log(`   Missing from test:    ${missing.length}`);
  console.log("=".repeat(80));

  if (falsePositives.length > 0) {
    console.log(`\nFALSE POSITIVES (in test but not mined):`);
    console.log("   These selectors appear in the contract but weren't in our target list.");
    console.log("   They might be from Solidity's internal functions or duplicates.\n");
    falsePositives.forEach((selector, i) => {
      console.log(`   ${i + 1}. ${selector}`);
    });
  }

  if (missing.length > 0) {
    console.log(`\nMISSING FROM TEST (mined but not in test output):`);
    console.log("   These selectors were mined but don't appear in the test output.");
    console.log("   This might indicate a problem with the contract generation.\n");
    missing.forEach((selector, i) => {
      console.log(`   ${i + 1}. ${selector}`);
    });
  }

  if (falsePositives.length === 0 && missing.length === 0) {
    console.log("\nPERFECT MATCH!");
    console.log("   All selectors match exactly between test output and mined data.");
  }

  console.log("\n" + "=".repeat(80));

  return { falsePositives, missing, correct };
}

function analyzeFalsePositives(falsePositives: string[], metadata: MetadataFile): void {
  if (falsePositives.length === 0) return;

  console.log(`\nDETAILED ANALYSIS OF FALSE POSITIVES:\n`);

  falsePositives.forEach((selector) => {
    console.log(`Selector: ${selector}`);

    const hex = selector.slice(2);
    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    const indexByte = parseInt(hex.slice(6, 8), 16);

    console.log(`  RGB: (${r}, ${g}, ${b})`);
    console.log(`  Index byte: ${indexByte} (0x${hex.slice(6, 8)})`);
    console.log(`  Color: rgb(${r}, ${g}, ${b})`);

    const matchingPixels = metadata.selectorsData.filter((s) => {
      const targetR = parseInt(s.slice(0, 2), 16);
      const targetG = parseInt(s.slice(2, 4), 16);
      const targetB = parseInt(s.slice(4, 6), 16);
      return targetR === r && targetG === g && targetB === b;
    });

    if (matchingPixels.length > 0) {
      console.log(`  WARNING: RGB matches ${matchingPixels.length} target pixel(s), but with different index byte:`);
      matchingPixels.forEach((p) => {
        const targetIndex = parseInt(p.slice(6, 8), 16);
        console.log(
          `     Target: 0x${p} (index: ${targetIndex}, position in array: ${metadata.selectorsData.indexOf(p)})`,
        );
      });
    } else {
      console.log(`  ERROR: RGB does not match any target pixels`);
    }

    console.log("");
  });
}

// Main function
function main(): void {
  console.log("\n" + "=".repeat(80));
  console.log("SELECTOR VERIFICATION TOOL");
  console.log("=".repeat(80) + "\n");

  const testSelectors = extractSelectorsFromTest();

  if (testSelectors.length === 0) {
    console.log("No selectors found in test output. Exiting.");
    process.exit(1);
  }

  const { minedSelectors, metadata } = loadMinedSelectors();
  const { falsePositives, missing, correct } = compareSelectors(testSelectors, minedSelectors);

  if (falsePositives.length > 0) {
    analyzeFalsePositives(falsePositives, metadata);
  }

  console.log("\n" + "=".repeat(80));
  console.log("SUMMARY");
  console.log("=".repeat(80));
  console.log(`Correct matches:    ${correct.length}`);
  console.log(`False positives:   ${falsePositives.length}`);
  console.log(`Missing from test: ${missing.length}`);

  if (falsePositives.length === 0 && missing.length === 0) {
    console.log("\nAll selectors verified successfully!");
    process.exit(0);
  } else {
    console.log("\nVerification found discrepancies. Review the details above.");
    process.exit(1);
  }
}

main();
