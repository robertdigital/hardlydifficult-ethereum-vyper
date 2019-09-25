module.exports = {
  env: {
    commonjs: true,
    es6: true,
    node: true,
  },
  extends: [
    'airbnb-base',
  ],
  globals: {
    Atomics: 'readonly',
    SharedArrayBuffer: 'readonly',
    artifacts: 'readonly',
    contract: 'readonly',
    before: 'readonly',
    it: 'readonly',
    assert: 'readonly',
    after: 'readonly'
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  rules: {
    'no-plusplus': 0,
    'no-await-in-loop': 0,
  },
};
