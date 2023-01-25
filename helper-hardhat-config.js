const networkConfig = {
  42161: {
    borrowerOperations: "0x3eEDF348919D130954929d4ff62D626f26ADBFa2",
    hintHelpers: "0xF9b46Bff75D185A8Ffbf74072dc9c698e1EC6851",
    vestaParams: "0x5F51B0A5E940A3a20502B5F59511B13788Ec6DDB",
    troveManager: "0x100EC08129e0FD59959df93a8b914944A3BbD5df",
    priceFeed: "0xd218Ba424A6166e37A454F8eCe2bf8eB2264eCcA",
    sortedTroves: "0x62842ceDFe0F7D203FC4cFD086a6649412d904B5",
    VSTStable: "0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17",
    FRAX: "0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F",
    curveFactoryPool: "0x59bF0545FCa0E5Ad48E13DA269faCD2E8C886Ba4",
  },
  31337: {
    borrowerOperations: "0x3eEDF348919D130954929d4ff62D626f26ADBFa2",
    hintHelpers: "0xF9b46Bff75D185A8Ffbf74072dc9c698e1EC6851",
    vestaParams: "0x5F51B0A5E940A3a20502B5F59511B13788Ec6DDB",
    troveManager: "0x100EC08129e0FD59959df93a8b914944A3BbD5df",
    priceFeed: "0xd218Ba424A6166e37A454F8eCe2bf8eB2264eCcA",
    sortedTroves: "0x62842ceDFe0F7D203FC4cFD086a6649412d904B5",
    VSTStable: "0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17",
    FRAX: "0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F",
    curveFactoryPool: "0x59bF0545FCa0E5Ad48E13DA269faCD2E8C886Ba4",
  },
};

const deployedContractsPath = "./deployments/deployedContracts.json";

module.exports = { networkConfig, deployedContractsPath };
