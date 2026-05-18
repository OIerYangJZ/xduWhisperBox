import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _title = '隐私政策';
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
            title: '引言',
            content:
                '西电树洞（以下简称"我们"）非常重视用户的隐私和个人信息保护。本隐私政策旨在向您说明我们如何收集、使用、存储和保护您的信息。\n\n'
                '请您在使用我们的服务前，仔细阅读并了解本隐私政策。如果您不同意本隐私政策的任何内容，请停止使用我们的服务。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '一、信息收集',
            content:
                '我们收集的信息包括您主动提供的信息以及您使用服务时自动收集的信息：\n\n'
                '【主动提供的信息】\n'
                '• 注册信息：校园邮箱、昵称、密码\n'
                '• 个人资料：头像、自愿填写的个人信息\n'
                '• 内容信息：发布的帖子、评论、私信内容\n'
                '• 其他您主动提供的信息\n\n'
                '【自动收集的信息】\n'
                '• 设备信息：设备类型、操作系统、浏览器类型\n'
                '• 日志信息：访问时间、浏览记录、操作行为\n'
                '• 位置信息：IP地址对应的地理位置（仅精确到城市级别）',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '二、信息使用',
            content:
                '我们收集的信息将用于以下目的：\n\n'
                '• 提供和改进服务：为您展示内容、处理您的操作请求\n'
                '• 账号管理：注册、登录、身份验证、账号安全\n'
                '• 内容审核：检测和处理违规内容\n'
                '• 沟通联系：向您发送服务通知、回复您的咨询\n'
                '• 统计分析：分析服务使用情况，优化产品体验\n'
                '• 安全保护：识别和防止安全威胁，保障平台安全',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '三、信息存储',
            content:
                '【存储地点】\n'
                '您的信息将存储在中华人民共和国境内的服务器上。\n\n'
                '【存储期限】\n'
                '• 账号信息：在您注销账号前持续保存\n'
                '• 内容信息：在您注销账号后保留必要期限后删除\n'
                '• 日志信息：保留期限不超过法律规定或监管要求\n\n'
                '【数据安全】\n'
                '我们采用行业标准的安全措施保护您的信息，包括数据加密、访问控制、安全审计等。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '四、信息共享',
            content:
                '我们承诺不会出售您的个人信息。在以下情况下，我们可能会共享您的信息：\n\n'
                '• 法律法规要求：依据法律、司法机关或监管机构的要求\n'
                '• 安全保护：用于保护国家安全、公共安全、他人权益\n'
                '• 服务提供商：在必要范围内向提供技术支持的服务商共享\n'
                '• 合并收购：业务重组、合并时进行转让（需通知您并获取同意）',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '五、用户权利',
            content:
                '您对自己的个人信息享有以下权利：\n\n'
                '【访问权】\n'
                '您有权访问您的账号信息和个人资料。\n\n'
                '【更正权】\n'
                '您有权更正不准确的个人信息。\n\n'
                '【删除权】\n'
                '您有权申请删除您的个人信息或注销账号。\n\n'
                '【撤回同意权】\n'
                '您有权撤回对信息收集的同意（可能影响部分服务功能）。\n\n'
                '【投诉权】\n'
                '您有权向监管部门投诉个人信息处理行为。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '六、Cookies和类似技术',
            content:
                '我们可能使用Cookies和类似技术来提升您的使用体验，包括：\n\n'
                '• 记住您的登录状态\n'
                '• 保存您的偏好设置\n'
                '• 分析网站流量和使用情况\n\n'
                '您可以通过浏览器设置管理Cookies，但禁用Cookies可能影响部分功能。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '七、未成年人保护',
            content:
                '我们的服务主要面向西安电子科技大学在校师生。\n\n'
                '如果您是未满18周岁的未成年人，请在监护人的陪同下阅读本隐私政策，并在取得监护人同意后使用我们的服务。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '八、隐私政策更新',
            content:
                '我们可能不时更新本隐私政策。更新后的隐私政策将在本平台公布。\n\n'
                '重大变更时，我们将通过适当方式通知您。继续使用我们的服务即表示您同意更新后的隐私政策。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '九、联系我们',
            content:
                '如您对本隐私政策有任何疑问或建议，请通过以下方式联系我们：\n\n'
                '• 发送邮件至平台管理员邮箱\n'
                '• 通过站内私信联系管理员\n\n'
                '我们将在合理时间内回复您的请求。',
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
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
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
              '西电树洞 · 校园匿名社交平台\n我们致力于保护您的个人信息安全',
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
