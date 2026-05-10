module.exports = {
  overrides: [
    {
      test: /^(?!.*node_modules).*$/,
      presets: ['module:react-native-builder-bob/babel-preset'],
    },
    {
      test: /node_modules/,
      presets: ['module:@react-native/babel-preset'],
    },
  ],
};
