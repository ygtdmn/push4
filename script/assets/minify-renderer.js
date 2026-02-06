#!/usr/bin/env node
/**
 * Minifies renderer-v2-original.html into renderer-v2.html
 * Preserves template placeholders: {{FILE_URIS}}, {{BLOCK_INTERVAL}}, {{CORE_ADDRESS}}
 * 
 * Usage: npm install html-minifier-terser && node minify-renderer.js
 */

const fs = require('fs');
const path = require('path');
const { minify } = require('html-minifier-terser');

const inputFile = path.join(__dirname, 'renderer-v2-original.html');
const outputFile = path.join(__dirname, 'renderer-v2.html');

async function run() {
    let html = fs.readFileSync(inputFile, 'utf8');

    // Protect template placeholders by replacing them temporarily
    const placeholders = {};
    let idx = 0;
    html = html.replace(/\{\{([A-Z_]+)\}\}/g, (match) => {
        const key = `PLACEHOLDER${idx++}PLACEHOLDER`;
        placeholders[key] = match;
        return key;
    });

    const minified = await minify(html, {
        collapseWhitespace: true,
        removeComments: true,
        removeRedundantAttributes: true,
        removeEmptyAttributes: true,
        minifyCSS: true,
        minifyJS: true,
    });

    // Restore template placeholders
    let result = minified;
    for (const [key, value] of Object.entries(placeholders)) {
        result = result.replace(new RegExp(key, 'g'), value);
    }

    fs.writeFileSync(outputFile, result);

    const origSize = fs.statSync(inputFile).size;
    const minSize = fs.statSync(outputFile).size;
    const savings = ((1 - minSize / origSize) * 100).toFixed(1);

    console.log(`Minified: ${inputFile}`);
    console.log(`Output:   ${outputFile}`);
    console.log(`Original: ${origSize} bytes`);
    console.log(`Minified: ${minSize} bytes`);
    console.log(`Savings:  ${savings}%`);
}

run().catch(console.error);
