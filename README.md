
本代码目前包括内容：  
1.单级轴流压缩机代码axial_compressor_design，资料来源于《轴流压缩机原理与气动设计》，进行初步验证，与ebslion试验结果对比，在低压缩比和低温度下拟合较差，高温情况下尚可，整体上不如带有级间损失的多级压缩机代码；后续可以抛开资料额外设计或者修改完善公式；  
2.单换热器代码GasLiquidHXDesign，资料来源于网络，未进行验证，使用逆流式换热；  
3.带有级间损失和级间换热的多级轴流式压缩机代码multi_stage_compressor_system，实现过程来源于循环调用axial_compressor_design和GasLiquidHXDesign，带有末级冷却，未进行验证；  
4.单级离心式压缩机代码centrifugal_compressor_calculation，资料来源于网络，未进行验证；
5.载热流体与热罐换热代码thermal_storage_simulation，资料来源于caes中的simulink模型，与simulink进行过初步验证，存在差异，但初步认为可行；  
注意：  
1.每个函数均带有一个test代码，作初步的功能验证
