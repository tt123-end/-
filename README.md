# 里猎手外观包 v1.73-art（测试版）

基于猎手 v1.72，增加66项道具外观、多方向素材及EID中英文外观说明。保留原战斗逻辑与Stats+数值接口。目标环境：以撒的结合：忏悔+，启用匹配版本的REPENTOGON。

## 下载

- [完整Mod安装包](deliverables/Hunter_v1.73-art_test.zip)
- [美术源图及制作文件](deliverables/Hunter_art_sources.zip)
- [66项道具设计清单](deliverables/COSTUME_CATALOG.md)
- [安装与验证说明](zzzz_revolver_samson/ART_PACK_README.md)

点击ZIP文件后选择Download raw file下载。

## 安装

完全退出游戏，将旧猎手文件夹移出mods备份，再解压安装包，把zzzz_revolver_samson放入mods。只启用一份猎手，无需改动EID或Stats+文件。

也可直接使用本仓库中的zzzz_revolver_samson文件夹。

## 当前验证状态

Lua语法、XML/ANM2解析、资源路径和裁切边界、透明通道、服装增删模拟检查及ZIP完整性检查通过。模拟检查覆盖双人独立状态、主动触发、道具移除、角色切换、白火游魂恢复和EID说明追加。

尚未进行游戏实测。本版是外观测试版；服装叠加、特殊动画、主动效果组合及继续游戏后的恢复需要在游戏中验收。

## 离线合成预览

下图按动画坐标离线合成，不是游戏截图。

![里猎手外观预览](deliverables/costume-preview.png)

## 来源

原角色与战斗代码来自用户提供的猎手Mod。道具外观覆盖范围及组织方式参照用户提供的Marisa as Cain v1.16；新配饰由图像生成工具按里猎手主题制作。未打包参考Mod、EID或Stats+本体。不对原有素材及第三方内容另行声明授权。
