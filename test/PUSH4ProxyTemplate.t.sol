// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";

contract PUSH4ProxyTemplateTest is Test {
    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4ProxyTemplate public proxyTemplate;

    address public owner = address(this);

    function setUp() public {
        push4 = new PUSH4();
        push4Core = new PUSH4Core(address(push4), owner);
        proxyTemplate = new PUSH4ProxyTemplate(address(push4), address(push4Core));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate expected luminance using the same formula as the contract
    function _calculateLuminance(uint8 r, uint8 g, uint8 b) internal pure returns (uint16) {
        return uint16((uint32(r) * 299 + uint32(g) * 587 + uint32(b) * 114) / 1000);
    }

    /// @notice Calculate expected pseudorandom value for off-black transformation
    function _calculatePseudoRandom(uint8 r, uint8 g, uint8 b, uint8 index) internal pure returns (uint8) {
        return uint8((uint16(index) * 7 + uint16(r) + uint16(g) + uint16(b)) % 16);
    }

    /// @notice Build a bytes4 from individual components
    function _buildSelector(uint8 r, uint8 g, uint8 b, uint8 index) internal pure returns (bytes4) {
        return bytes4(bytes.concat(bytes1(r), bytes1(g), bytes1(b), bytes1(index)));
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test: any random bytes4 returns correct result
    function testFuzz_execute_returnsCorrectResult(bytes4 selector) public view {
        uint8 r = uint8(selector[0]);
        uint8 g = uint8(selector[1]);
        uint8 b = uint8(selector[2]);
        uint8 index = uint8(selector[3]);

        uint16 luminance = _calculateLuminance(r, g, b);
        bytes4 result = proxyTemplate.execute(selector);

        if (luminance >= 100) {
            // Light colors should be returned unchanged
            assertEq(result, selector, "Light color should be unchanged");
        } else {
            // Dark colors should be transformed to off-black
            uint8 expectedPseudo = _calculatePseudoRandom(r, g, b, index);
            bytes4 expectedResult = _buildSelector(expectedPseudo, expectedPseudo, expectedPseudo, index);
            assertEq(result, expectedResult, "Dark color transformation mismatch");
        }
    }

    /// @notice Fuzz test: light colors (luminance >= 100) are returned unchanged
    function testFuzz_execute_lightColorsUnchanged(uint8 r, uint8 g, uint8 b, uint8 index) public view {
        // Bound g to minimum 171 to guarantee luminance >= 100
        // luminance = (299*r + 587*g + 114*b) / 1000
        // When g >= 171: luminance >= (587 * 171) / 1000 = 100
        g = uint8(bound(uint256(g), 171, 255));

        bytes4 selector = _buildSelector(r, g, b, index);
        bytes4 result = proxyTemplate.execute(selector);

        // Verify luminance is indeed >= 100
        assertGe(_calculateLuminance(r, g, b), 100, "Luminance should be >= 100");
        assertEq(result, selector, "Light color should be returned unchanged");
    }

    /// @notice Fuzz test: dark colors (luminance < 100) are transformed correctly
    function testFuzz_execute_darkColorsTransformed(uint8 r, uint8 g, uint8 b, uint8 index) public view {
        // Bound to ensure luminance < 100
        vm.assume(_calculateLuminance(r, g, b) < 100);

        bytes4 selector = _buildSelector(r, g, b, index);
        bytes4 result = proxyTemplate.execute(selector);

        // Verify transformation
        uint8 expectedPseudo = _calculatePseudoRandom(r, g, b, index);

        // Extract result components
        uint8 resultR = uint8(result[0]);
        uint8 resultG = uint8(result[1]);
        uint8 resultB = uint8(result[2]);
        uint8 resultIndex = uint8(result[3]);

        // All color components should be the same (grayscale)
        assertEq(resultR, resultG, "Transformed R should equal G");
        assertEq(resultG, resultB, "Transformed G should equal B");

        // Color should be in off-black range (0-15)
        assertLt(resultR, 16, "Transformed color should be < 16");

        // Color should match expected pseudorandom value
        assertEq(resultR, expectedPseudo, "Transformed color should match pseudorandom");

        // Index should be preserved
        assertEq(resultIndex, index, "Index should be preserved");
    }

    /// @notice Fuzz test: index byte is always preserved
    function testFuzz_execute_indexAlwaysPreserved(bytes4 selector) public view {
        uint8 originalIndex = uint8(selector[3]);
        bytes4 result = proxyTemplate.execute(selector);
        uint8 resultIndex = uint8(result[3]);

        assertEq(resultIndex, originalIndex, "Index byte should always be preserved");
    }

    /// @notice Fuzz test: transformed colors are always in 0-15 range
    function testFuzz_execute_transformedColorsInOffBlackRange(uint8 r, uint8 g, uint8 b, uint8 index) public view {
        // Only test dark colors that will be transformed
        vm.assume(_calculateLuminance(r, g, b) < 100);

        bytes4 selector = _buildSelector(r, g, b, index);
        bytes4 result = proxyTemplate.execute(selector);

        uint8 resultR = uint8(result[0]);
        uint8 resultG = uint8(result[1]);
        uint8 resultB = uint8(result[2]);

        assertLt(resultR, 16, "R should be in 0-15 range");
        assertLt(resultG, 16, "G should be in 0-15 range");
        assertLt(resultB, 16, "B should be in 0-15 range");
    }

    /// @notice Fuzz test: luminance calculation is correct
    function testFuzz_luminanceCalculation(uint8 r, uint8 g, uint8 b) public pure {
        uint16 luminance = _calculateLuminance(r, g, b);

        // Verify luminance is within valid range (0-255)
        assertLe(luminance, 255, "Luminance should not exceed 255");

        // Verify the formula: max value = (255*299 + 255*587 + 255*114) / 1000 = 255
        // min value = 0
        uint16 expectedMax = uint16((uint32(255) * 299 + uint32(255) * 587 + uint32(255) * 114) / 1000);
        assertLe(luminance, expectedMax, "Luminance should not exceed theoretical max");
    }

    /// @notice Fuzz test: pseudorandom value is always in 0-15 range
    function testFuzz_pseudoRandomInRange(uint8 r, uint8 g, uint8 b, uint8 index) public pure {
        // Note: This is a pure function test - just validates the formula
        uint8 pseudo = uint8((uint16(index) * 7 + uint16(r) + uint16(g) + uint16(b)) % 16);
        assert(pseudo < 16);
    }

    /// @notice Fuzz test: same input always produces same output (deterministic)
    function testFuzz_execute_isDeterministic(bytes4 selector) public view {
        bytes4 result1 = proxyTemplate.execute(selector);
        bytes4 result2 = proxyTemplate.execute(selector);

        assertEq(result1, result2, "Same input should produce same output");
    }

    /// @notice Fuzz test: pure black (0,0,0) is correctly transformed to off-black
    function testFuzz_execute_pureBlackTransformed(uint8 index) public view {
        bytes4 selector = _buildSelector(0, 0, 0, index);
        bytes4 result = proxyTemplate.execute(selector);

        // Pure black has luminance 0, so it will be transformed
        // The pseudorandom value is: (index * 7 + 0 + 0 + 0) % 16 = (index * 7) % 16
        uint8 expectedPseudo = uint8((uint16(index) * 7) % 16);
        bytes4 expectedResult = _buildSelector(expectedPseudo, expectedPseudo, expectedPseudo, index);

        assertEq(result, expectedResult, "Pure black transformation should match expected");

        // Index should be preserved
        assertEq(uint8(result[3]), index, "Index should be preserved");

        // Result should be grayscale
        assertEq(uint8(result[0]), uint8(result[1]), "Result should be grayscale R=G");
        assertEq(uint8(result[1]), uint8(result[2]), "Result should be grayscale G=B");

        // Result color should be in off-black range
        assertLt(uint8(result[0]), 16, "Transformed color should be in 0-15 range");
    }

    /// @notice Fuzz test: pure white (255,255,255) is never transformed
    function testFuzz_execute_pureWhiteUnchanged(uint8 index) public view {
        bytes4 selector = _buildSelector(255, 255, 255, index);
        bytes4 result = proxyTemplate.execute(selector);

        // Pure white has luminance 255, so it should be unchanged
        assertEq(result, selector, "Pure white should be unchanged");
    }

    /*//////////////////////////////////////////////////////////////
                          BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test: luminance exactly at boundary (99 vs 100)
    function testFuzz_execute_luminanceBoundary(uint8 index) public view {
        // Find RGB values that give luminance exactly 99 and 100

        // luminance = (299*r + 587*g + 114*b) / 1000
        // For luminance = 100: 299*r + 587*g + 114*b = 100000
        // For luminance = 99: 299*r + 587*g + 114*b = 99000

        // Test case: r=0, g=170 gives luminance = (587*170)/1000 = 99.79 ≈ 99
        bytes4 darkSelector = _buildSelector(0, 170, 0, index);
        uint16 darkLuminance = _calculateLuminance(0, 170, 0);
        bytes4 darkResult = proxyTemplate.execute(darkSelector);

        if (darkLuminance < 100) {
            // Should be transformed
            uint8 resultR = uint8(darkResult[0]);
            assertLt(resultR, 16, "Dark boundary should be transformed to off-black");
        } else {
            // Should be unchanged
            assertEq(darkResult, darkSelector, "Light boundary should be unchanged");
        }

        // Test case: r=0, g=171 gives luminance = (587*171)/1000 = 100.37 ≈ 100
        bytes4 lightSelector = _buildSelector(0, 171, 0, index);
        uint16 lightLuminance = _calculateLuminance(0, 171, 0);
        bytes4 lightResult = proxyTemplate.execute(lightSelector);

        if (lightLuminance >= 100) {
            assertEq(lightResult, lightSelector, "Light boundary should be unchanged");
        } else {
            uint8 resultR = uint8(lightResult[0]);
            assertLt(resultR, 16, "Dark boundary should be transformed");
        }
    }

    /// @notice Test all 256 index values with fixed dark color
    function test_execute_allIndexValuesWithDarkColor() public view {
        uint8 r = 10;
        uint8 g = 10;
        uint8 b = 10;

        // Verify this is a dark color
        assertLt(_calculateLuminance(r, g, b), 100, "Test color should be dark");

        for (uint16 i = 0; i < 256; i++) {
            uint8 index = uint8(i);
            bytes4 selector = _buildSelector(r, g, b, index);
            bytes4 result = proxyTemplate.execute(selector);

            // Verify transformation
            uint8 expectedPseudo = _calculatePseudoRandom(r, g, b, index);
            bytes4 expectedResult = _buildSelector(expectedPseudo, expectedPseudo, expectedPseudo, index);

            assertEq(result, expectedResult, "Transformation mismatch for index");
        }
    }

    /// @notice Test all 256 index values with fixed light color
    function test_execute_allIndexValuesWithLightColor() public view {
        uint8 r = 200;
        uint8 g = 200;
        uint8 b = 200;

        // Verify this is a light color
        assertGe(_calculateLuminance(r, g, b), 100, "Test color should be light");

        for (uint16 i = 0; i < 256; i++) {
            uint8 index = uint8(i);
            bytes4 selector = _buildSelector(r, g, b, index);
            bytes4 result = proxyTemplate.execute(selector);

            assertEq(result, selector, "Light color should be unchanged for all indices");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsPush4() public view {
        assertEq(address(proxyTemplate.push4()), address(push4));
    }

    function test_constructor_setsPush4Core() public view {
        assertEq(address(proxyTemplate.push4core()), address(push4Core));
    }

    /*//////////////////////////////////////////////////////////////
                          SPECIFIC VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test known dark colors are transformed correctly
    function test_execute_knownDarkColors() public view {
        // Test pure black at index 0
        bytes4 black = _buildSelector(0, 0, 0, 0);
        bytes4 blackResult = proxyTemplate.execute(black);
        uint8 expectedBlackPseudo = _calculatePseudoRandom(0, 0, 0, 0);
        assertEq(blackResult, _buildSelector(expectedBlackPseudo, expectedBlackPseudo, expectedBlackPseudo, 0));

        // Test dark brown (typical in the artwork)
        bytes4 darkBrown = _buildSelector(20, 15, 10, 5);
        bytes4 brownResult = proxyTemplate.execute(darkBrown);
        uint8 expectedBrownPseudo = _calculatePseudoRandom(20, 15, 10, 5);
        assertEq(brownResult, _buildSelector(expectedBrownPseudo, expectedBrownPseudo, expectedBrownPseudo, 5));
    }

    /// @notice Test known light colors remain unchanged
    function test_execute_knownLightColors() public view {
        // Pure white
        bytes4 white = _buildSelector(255, 255, 255, 10);
        assertEq(proxyTemplate.execute(white), white);

        // Light gray
        bytes4 lightGray = _buildSelector(200, 200, 200, 7);
        assertEq(proxyTemplate.execute(lightGray), lightGray);

        // Bright red
        bytes4 brightRed = _buildSelector(255, 100, 100, 3);
        assertEq(proxyTemplate.execute(brightRed), brightRed);

        // Bright green (g=255 gives high luminance)
        bytes4 brightGreen = _buildSelector(0, 200, 0, 12);
        assertEq(proxyTemplate.execute(brightGreen), brightGreen);
    }

    /// @notice Fuzz test: verify no overflow in luminance calculation
    function testFuzz_execute_noOverflowInLuminance(uint8 r, uint8 g, uint8 b, uint8 index) public view {
        // This should never revert due to overflow
        bytes4 selector = _buildSelector(r, g, b, index);
        proxyTemplate.execute(selector);
    }

    /// @notice Fuzz test: verify pseudorandom distribution varies with index
    function testFuzz_execute_pseudoRandomVariesWithIndex(uint8 r, uint8 g, uint8 b) public pure {
        // Only test dark colors
        vm.assume(_calculateLuminance(r, g, b) < 100);

        // Different indices should produce different pseudorandom values (with high probability)
        uint8 count = 0;
        uint8 lastValue = 0;

        for (uint8 i = 0; i < 16; i++) {
            uint8 pseudo = _calculatePseudoRandom(r, g, b, i);
            if (i == 0 || pseudo != lastValue) {
                count++;
            }
            lastValue = pseudo;
        }

        // With the formula (index*7 + r + g + b) % 16, different indices should give different values
        // At least some variation should exist
        assertGt(count, 1, "Pseudorandom should vary with index");
    }

    /*//////////////////////////////////////////////////////////////
                          GRAYSCALE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test: transformed colors are always grayscale (R = G = B)
    function testFuzz_execute_transformedIsGrayscale(bytes4 selector) public view {
        uint8 r = uint8(selector[0]);
        uint8 g = uint8(selector[1]);
        uint8 b = uint8(selector[2]);

        if (_calculateLuminance(r, g, b) < 100) {
            bytes4 result = proxyTemplate.execute(selector);

            uint8 resultR = uint8(result[0]);
            uint8 resultG = uint8(result[1]);
            uint8 resultB = uint8(result[2]);

            assertEq(resultR, resultG, "Transformed must be grayscale: R == G");
            assertEq(resultG, resultB, "Transformed must be grayscale: G == B");
        }
    }
}

