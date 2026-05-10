/**
 * @type {import('@react-native-community/cli-types').UserDependencyConfig}
 */
module.exports = {
  dependency: {
    platforms: {
      android: {
        cxxModuleCMakeListsModuleName: 'react-native-ratex',
        cxxModuleCMakeListsPath: 'CMakeLists.txt',
      },
    },
  },
};
