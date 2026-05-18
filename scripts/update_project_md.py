import codecs

with codecs.open('c:/Users/24045/Desktop/xduWhisperBox/PROJECT.md', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')

new_row = '| 0.1.0+15 | 2026-03-28 | **修复「我的帖子」Tab 显示所有用户帖子**：① 后端 `services/_db_service.py` 的 `list_posts()` 新增 `include_rejected` 参数（默认 False），修复原 `handle_get_posts_mine` 传入无效参数导致 TypeError；② 前端 `repositories/post_repository.dart` 的 `fetchMyPosts()` 删除 mock 回退（`mockPosts.take(3)`），API 失败时正确返回空列表而非显示虚假数据 |'

inserted = False
for i, line in enumerate(lines):
    if '0.1.0+14' in line and '移动端消息页优化' in line:
        lines.insert(i, new_row)
        inserted = True
        print(f'Inserted new version row at line {i}')
        break

if inserted:
    with codecs.open('c:/Users/24045/Desktop/xduWhisperBox/PROJECT.md', 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print('PROJECT.md updated successfully')
else:
    print('ERROR: Could not find the target line to insert before')
