# Axial-Compressor-Design
本MATLAB工具实现了多级轴流压缩机的热力计算功能，基于《轴流压缩机原理与气动设计》的理论框架。该工具可根据用户输入的工质参数、边界条件和设计参数，计算各级压缩过程的温度、压力、速度等关键参数，并输出压缩机整体性能指标。  
使用方法：matlab使用parameters_input作为数据输入和结果呈现，AxialCompressor为计算方法  
<img width="441" height="373" alt="image" src="https://github.com/user-attachments/assets/364431a5-d4b4-44f9-a3a5-343259900691" />    
参数输入  
<img width="888" height="544" alt="image" src="https://github.com/user-attachments/assets/1fd10cf3-b6ab-42dc-9d7e-75c05bfd117f" />  

注意：  
1.本代码尚未其他模型或者软件检验；  
2.本代码使用等绝热能量头分配法进行计算，属于简化计算；  
3.本计算过程重热计算方法并未提供多变效率，因此重热系数默认使用1.05；  
4.参考文献仅《轴流压缩机原理与气动设计》，无其他参考文献。
