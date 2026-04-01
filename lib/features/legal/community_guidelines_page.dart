import 'package:flutter/material.dart';

class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});

  static const String _title = '社区规范';
  static const String _lastUpdated = '2026年3月20日';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
        backgroundColor: const Color(0xFF0E7490),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: '社区宗旨',
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFF059669),
            content:
                '西电树洞致力于打造一个健康、积极、友善的校园匿名社交平台。我们鼓励真实表达、理性讨论、相互尊重，让每一位西电学子都能在这里找到归属感。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '一、言论自由与责任',
            icon: Icons.record_voice_over_outlined,
            iconColor: const Color(0xFF0E7490),
            content:
                '我们珍视每一位用户的表达权利，同时呼吁大家：\n\n'
                '• 理性表达：对事不对人，避免情绪化攻击\n'
                '• 真实分享：分享真实经历和感受，不造谣传谣\n'
                '• 独立思考：对信息保持理性判断，不盲从跟风\n'
                '• 文明用语：使用文明语言，尊重不同观点',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '二、绝对禁止内容',
            icon: Icons.block_outlined,
            iconColor: const Color(0xFFDC2626),
            isWarning: true,
            content:
                '以下内容一经发现，将立即删除并视情节轻重给予处罚：\n\n'
                '【法律法规禁止】\n'
                '• 违反宪法确定的基本原则的内容\n'
                '• 危害国家安全、泄露国家秘密的内容\n'
                '• 颠覆国家政权、破坏国家统一的内容\n'
                '• 损害国家荣誉和利益的内容\n\n'
                '【违法犯罪行为】\n'
                '• 宣传封建迷信、邪教组织的内容\n'
                '• 涉及赌博、毒品、武器交易的内容\n'
                '• 其他违反法律法规的内容',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '三、严重违规内容',
            icon: Icons.warning_amber_outlined,
            iconColor: const Color(0xFFEA580C),
            isWarning: true,
            content:
                '以下内容严重破坏社区环境，一经发现将从严处理：\n\n'
                '• 淫秽色情、暴力血腥内容\n'
                '• 侮辱、诽谤、骚扰他人的内容\n'
                '• 侵犯他人隐私的信息（如未经同意的个人信息）\n'
                '• 恶意造谣、传播虚假信息\n'
                '• 人肉搜索、网络暴力行为\n'
                '• 种族歧视、地域歧视内容\n'
                '• 恶意营销、商业广告（除平台允许外）',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '四、一般违规内容',
            icon: Icons.edit_note_outlined,
            iconColor: const Color(0xFFD97706),
            content:
                '以下内容不鼓励发布，频繁发布可能导致功能限制：\n\n'
                '• 与校园生活无关的水贴、纯表情贴\n'
                '• 低质量、无实质内容的灌水帖\n'
                '• 重复发布相同或相似内容\n'
                '• 含有不文明用语、攻击性语言的内容',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '五、违规处罚',
            icon: Icons.gavel_outlined,
            iconColor: const Color(0xFF7C3AED),
            content:
                '根据违规情节严重程度，采取以下处罚措施：\n\n'
                '【轻度违规】\n'
                '• 内容删除\n'
                '• 警告通知\n'
                '• 短期禁言（1-7天）\n\n'
                '【中度违规】\n'
                '• 内容删除\n'
                '• 中期禁言（7-30天）\n'
                '• 限制部分功能\n\n'
                '【严重违规】\n'
                '• 永久封禁账号\n'
                '• 情节严重者移交相关部门处理',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '六、举报机制',
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFF0284C7),
            content:
                '发现违规内容时，欢迎您积极举报：\n\n'
                '• 点击帖子右下角的"举报"按钮\n'
                '• 选择违规类型并描述详情\n'
                '• 提交后管理员将尽快处理\n\n'
                '我们会保护举报人的隐私，对打击报复行为零容忍。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '七、优质内容倡议',
            icon: Icons.thumb_up_outlined,
            iconColor: const Color(0xFF059669),
            content:
                '我们倡议大家积极发布优质内容：\n\n'
                '• 【学习分享】考研经验、课程评价、技能教程\n'
                '• 【校园生活】活动见闻、食堂探店、生活技巧\n'
                '• 【情感交流】心事倾诉、困惑求助、成长感悟\n'
                '• 【互助问答】信息咨询、资源共享、经验交流\n\n'
                '优质内容将有机会获得更多曝光和推荐。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '八、免责声明',
            icon: Icons.info_outline,
            iconColor: const Color(0xFF6B7280),
            content:
                '• 用户发布的内容仅代表个人观点，不代表平台立场\n'
                '• 平台对用户之间的私下交易、纠纷不承担责任\n'
                '• 因用户违规行为造成的法律责任由发布者承担\n'
                '• 平台保留对社区规则的最终解释权',
          ),
          const SizedBox(height: 32),
          _buildFooter(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0E7490), Color(0xFF155E75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.groups_outlined, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            _title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '最后更新：$_lastUpdated',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isWarning
            ? Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isWarning ? const Color(0xFF991B1B) : const Color(0xFF155E75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isWarning ? const Color(0xFF7F1D1D) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0E7490).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, color: Color(0xFF0E7490), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '西电树洞 · 校园匿名社交平台\n共建清朗网络空间，需要你我共同努力',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
