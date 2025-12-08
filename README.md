# multi_stage_compressor_system
本MATLAB工具实现了多级轴流压缩机的热力计算功能，基于《轴流压缩机原理与气动设计》的理论框架。该工具可根据用户输入的工质参数、边界条件和设计参数，计算各级压缩过程的温度、压力、速度等关键参数，并输出压缩机整体性能指标。  
使用方法：matlab使用multi_stage_compressor_system_test作为数据输入和结果呈现  
<img width="902" height="514" alt="image" src="https://github.com/user-attachments/assets/6f3d0558-de61-43a4-a424-bd535e4c433f" />  
注意：  
1.本代码实现是通过循环调用单级压缩机代码和换热器代码实现功能；  
2.单级压缩机代码和ebslion仿真结果在较低温度时有较为明显的区别，预估还需进行公式改善；  
3.后续可以嵌套其他部件，如低温罐、储气洞穴等部件；  
4.代码构建思路与caes中simulink思路一致，但未进行对比验证。
