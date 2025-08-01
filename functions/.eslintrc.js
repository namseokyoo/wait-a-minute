module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
    sourceType: "module",
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
  },
};
