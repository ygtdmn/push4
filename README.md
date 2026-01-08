# PUSH4

A heavily compressed and dithered down version of Barnett Newman's **Onement I**, encoded in 375 smart contract function
selectors.

## Overview

PUSH4 encodes image data directly into Ethereum function selectors. Each pixel of the artwork is represented by a unique
4-byte function selector where:

- **Bytes 0-2**: RGB color values
- **Byte 3**: Column index for spatial positioning

The image is a 15×25 pixel representation of Newman's iconic "zip" painting, with color variations applied to create a
dithered aesthetic.

## Architecture

The project consists of three main contracts:

### PUSH4.sol

The main contract containing 375 functions, each with a carefully mined selector that encodes pixel data. Each function
returns its own `msg.sig` (or a transformed version via proxy).

### PUSH4Core.sol

An ERC-721 token that manages the artwork. Features:

- Single token (TOKEN_ID = 0)
- **Carved Mode**: Renders the original selectors as pixels
- **Executed Mode**: Calls each function and uses the return value as pixel data (enables dynamic transformations via
  proxy)
- 60-day grace period for configuration after deployment
- Implements the [Sculpture interface](https://worldcomputersculpture.garden/)

### PUSH4Renderer.sol

On-chain SVG renderer that:

- Extracts selectors from PUSH4 bytecode using `EXTCODECOPY`
- Sorts pixels by column index (last byte)
- Generates SVG image and metadata data URIs

### PUSH4RendererRouter.sol

A router contract that delegates rendering to another renderer contract. This allows changing the underlying renderer
without the 60-day grace period limit imposed by PUSH4Core. Features:

- **setRenderer**: Change the underlying renderer at any time (owner only)
- **lockRenderer**: Permanently lock the renderer, preventing future changes (irreversible)
- All IPUSH4Renderer functions pass through to the underlying renderer

## Deployed Addresses

Both Sepolia and Mainnet:

| Contract               | Address                                      |
| ---------------------- | -------------------------------------------- |
| PUSH4                  | `0x000000630bf663df3ff850DD34a28Fb7D4d52170` |
| PUSH4Core              | `0x00000063266aAAeDD489e4956153855626E44061` |
| PUSH4Renderer (Legacy) | `0x00000063Bbe182593913e09b8A481D58ADc31042` |
| PUSH4RendererRouter    | `0x000000636fac63f4f4c12c8674fb5d11f9a08753` |

Mainnet (V2):

| Contract               | Address                                      |
| ---------------------- | -------------------------------------------- |
| PUSH4ProxyFactory      | `0x996815bc3a8eb22ab254f2709b414b39a51e729e` |
| PUSH4RendererV2        | `0x9f6bf49c22714058dbb3f1b6a09ce6b28c8cc031` |
| PUSH4OrchestratorProxy | `0xee7e4505828cbeb285cb78fd3daa4cf2caf587f3` |
| PUSH4MURIOperator      | `0xa42026ac5a6b0a55329e5f33e8a457460c4cf2c5` |
| PUSH4OriginalProxy     | `0xa797bb4f941fefab51b7307ba09a566082903570` |

## How It Works

### 1. Image Generation

The `generate-image.ts` script creates a 15×25 pixel representation of Onement I:

- **Field color**: `#4C342E` (brownish)
- **Zip color**: `#AE5C37` (orange-ish)
- Color variations are applied for dithering
- Each pixel is encoded as 4 bytes: RGB + column index

### 2. Selector Mining

The CUDA-based miner (`function-selector-miner-cuda`) finds function names that hash to the target selectors:

- Uses GPU acceleration (optimized for RTX 4090)
- Finds function names like `f5890476424()` whose keccak256 hash produces the desired 4-byte selector
- Supports batch mining for efficiency

### 3. Contract Generation

The `generate-push4-contract.ts` script:

- Reads pixel data from JSON
- Mines selectors (or uses cached results)
- Generates the Solidity contract with 375 functions
- Saves progress to allow resumption if interrupted

## Scripts

| Script                      | Description                                             |
| --------------------------- | ------------------------------------------------------- |
| `bun run build`             | Compile contracts with Forge                            |
| `bun run test`              | Run Foundry tests                                       |
| `bun run generate:image`    | Generate pixel data and SVG preview                     |
| `bun run generate:contract` | Mine selectors and generate PUSH4.sol                   |
| `bun run verify:selectors`  | Verify all selectors are correctly embedded in bytecode |
| `bun run lint`              | Run Solhint and Forge formatter                         |
| `bun run prettier:check`    | Check formatting of JSON, MD, YML files                 |
| `bun run prettier:write`    | Fix formatting of JSON, MD, YML files                   |
| `bun run test:coverage`     | Generate test coverage report                           |

## Building the CUDA Miner

Requirements: CUDA Toolkit installed.

```bash
cd function-selector-miner-cuda

# Adjust CUDA_ARCH in Makefile for your GPU:
# sm_75 (RTX 20xx), sm_86 (RTX 30xx), sm_89 (RTX 40xx)

make
```

### Usage

Single selector:

```bash
./selector_miner_cuda "f" "()" "0x4f302900"
```

Batch mode:

```bash
./selector_miner_cuda --batch selectors.txt
```

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Bun](https://bun.sh/)
- CUDA Toolkit (for selector mining)

### Setup

```bash
bun install
forge build
```

### Generate New Image

```bash
bun run generate:image
# Outputs: ts-scripts/data/pixel-data.json and generated-image.svg
```

### Generate Contract

```bash
bun run generate:contract
# Mines selectors (GPU required) and generates src/PUSH4.sol
# Progress is saved to ts-scripts/data/selector-mining-progress.json
```

### Deploy

```bash
forge script script/Deploy.s.sol --broadcast --rpc-url sepolia
```

## How the Renderer Works

1. **Extract selectors**: Scans PUSH4 bytecode for `PUSH4` opcodes (0x63)
2. **Sort by column**: Orders pixels by the last byte (column index)
3. **Build SVG**: Creates `<rect>` elements with colors from first 3 bytes
4. **In Executed mode**: Calls each function and uses return values instead

## License

MIT

## Credits

- [Vectorized/function-selector-miner](https://github.com/Vectorized/function-selector-miner) - Original CPU miner
- [mochimodev/cuda-hashing-algos](https://github.com/mochimodev/cuda-hashing-algos) - CUDA keccak implementation
- Barnett Newman - Onement I (1948)
