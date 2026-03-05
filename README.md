# Resume Template Pro - 20 套可直接对接 OC/HTML 的简历模板

这批模板严格保持你提供的数据填充格式：
- 统一 DOM id：`name`、`job_intent`、`phone`、`email`、`location`、`birthday`、`avatar`、`self_eval`、`jobs`、`internships`、`projects`、`education`
- 统一函数签名：`setResumeData(d)`、`renderExperience(id, arr)`、`renderEducation(arr)`、`hideIfEmpty(id, arr)`

## 排版类型（更丰富）
- A 类：现代单栏（1,6,11,16）
- B 类：左侧边栏（2,7,12,17）
- C 类：时间轴风格（3,8,13,18）
- D 类：卡片网格（4,9,14,19）
- E 类：分栏头部（5,10,15,20）

## 使用方式
```html
<script>
setResumeData(yourResumeData);
</script>
```
