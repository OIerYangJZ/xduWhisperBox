import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const String _title = '用户协议';
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
            title: '一、服务条款的确认和接受',
            content:
                '欢迎使用西电树洞（以下简称"本平台"）。在使用本平台服务之前，请您仔细阅读本用户协议。\n\n'
                '您在使用本平台时，即表示您已阅读、理解并同意接受本协议的全部条款。如果您不同意本协议的任何内容，请停止使用本平台服务。\n\n'
                '本平台有权随时修改本协议，修改后的协议一经公布即生效。如果您继续使用本平台服务，视为您接受修改后的协议。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '二、服务说明',
            content:
                '本平台为西安电子科技大学在校师生提供校园匿名社交服务，包括但不限于：\n\n'
                '• 发布和浏览匿名帖子\n'
                '• 评论和互动功能\n'
                '• 私信交流\n'
                '• 举报违规内容\n\n'
                '本平台保留随时变更、中断或终止部分或全部服务的权利。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '三、用户注册与账号',
            content:
                '1. 注册资格\n'
                '   用户须为西安电子科技大学在校师生，使用校内邮箱（@stu.xidian.edu.cn 或 @xidian.edu.cn）进行注册。\n\n'
                '2. 账号安全\n'
                '   用户须妥善保管账号信息，因个人保管不当造成的损失，由用户自行承担。\n\n'
                '3. 账号注销\n'
                '   用户可申请注销账号，提交申请后需经管理员审核通过方可完成注销。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '四、用户行为规范',
            content:
                '用户在使用本平台时，应遵守以下行为规范：\n\n'
                '【禁止行为】\n'
                '• 发布违反法律法规的内容\n'
                '• 发布危害国家安全、社会稳定的内容\n'
                '• 发布侵犯他人合法权益的内容\n'
                '• 发布虚假信息或恶意造谣\n'
                '• 骚扰、诽谤、侮辱他人\n'
                '• 传播淫秽、色情、暴力内容\n'
                '• 商业广告、推广信息（除平台允许外）\n'
                '• 其他违反公序良俗的行为\n\n'
                '【鼓励行为】\n'
                '• 积极传播正能量\n'
                '• 分享有价值的校园信息\n'
                '• 友善交流，尊重他人\n'
                '• 举报违规内容，维护社区秩序',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '五、内容管理',
            content:
                '1. 本平台有权对用户发布的内容进行审核，对违规内容进行删除、屏蔽等处理。\n\n'
                '2. 用户发布的内容不代表本平台立场，本平台不对用户发布的内容承担责任。\n\n'
                '3. 因用户发布违规内容造成的法律责任，由发布者自行承担。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '六、隐私保护',
            content:
                '本平台重视用户隐私保护，具体政策请参阅《隐私政策》。\n\n'
                '用户在使用本平台时，即表示同意本平台按照隐私政策收集、使用、存储和保护用户信息。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '七、免责声明',
            content:
                '1. 本平台不对用户发布的内容的真实性、准确性、完整性进行保证。\n\n'
                '2. 因不可抗力导致的服务中断，本平台不承担责任。\n\n'
                '3. 用户因使用本平台服务而遭受的损失，本平台在法律允许范围内免责。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '八、协议修改',
            content:
                '本平台有权随时修改本协议，修改后的协议将在本平台公布。用户在修改后继续使用本平台服务，视为接受修改后的协议。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '九、联系我们',
            content:
                '如您对本协议有任何疑问，请通过以下方式联系我们：\n\n'
                '• 发送邮件至平台管理员邮箱\n'
                '• 通过站内私信联系管理员\n\n'
                '感谢您使用西电树洞！',
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
            child: const Icon(Icons.description_outlined, color: Colors.white, size: 32),
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

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E7490),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF155E75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Color(0xFF374151),
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
              '西电树洞 · 校园匿名社交平台\n本协议解释权归平台管理团队所有',
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
