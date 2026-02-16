import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользовательское соглашение'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Пользовательское соглашение',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Последнее обновление: Февраль 2026',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // 1. Общие положения
            _sectionTitle('1. Общие положения'),
            const SizedBox(height: 8),
            const Text(
              'Настоящее Пользовательское соглашение (далее — Соглашение) '
              'регулирует отношения между администрацией платформы EstateHub '
              '(estate-hub.ru) и пользователем (далее — Пользователь). '
              'Используя приложение или веб-сайт EstateHub, Пользователь '
              'подтверждает, что ознакомился с условиями настоящего Соглашения '
              'и принимает их в полном объёме.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 2. Регистрация аккаунта
            _sectionTitle('2. Регистрация аккаунта'),
            const SizedBox(height: 8),
            const Text(
              'Для доступа к функциям платформы необходима регистрация. '
              'При регистрации Пользователь обязуется:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem(
              'Указать действующий номер телефона, к которому Пользователь '
              'имеет доступ.',
            ),
            _bulletItem(
              'Создать только один аккаунт. Создание нескольких аккаунтов '
              'одним лицом запрещено и может повлечь блокировку.',
            ),
            _bulletItem(
              'Не передавать данные для входа в аккаунт третьим лицам.',
            ),
            const SizedBox(height: 24),

            // 3. Тарифные планы
            _sectionTitle('3. Тарифные планы'),
            const SizedBox(height: 8),
            const Text(
              'Платформа EstateHub предлагает несколько тарифных планов:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem(
              'Бесплатный — базовые возможности: просмотр объявлений, '
              'создание ограниченного числа объявлений.',
            ),
            _bulletItem(
              'Pro — расширенные возможности: увеличенное количество '
              'объявлений, приоритетное размещение, аналитика просмотров.',
            ),
            _bulletItem(
              'Premium — полный набор функций: неограниченное количество '
              'объявлений, продвижение, выделение в поиске, персональная '
              'поддержка.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Условия и стоимость тарифных планов могут быть изменены '
              'администрацией. Действующие пользователи будут уведомлены '
              'об изменениях заблаговременно.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 4. Правила размещения объявлений
            _sectionTitle('4. Правила размещения объявлений'),
            const SizedBox(height: 8),
            const Text(
              'При размещении объявлений Пользователь обязуется:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem(
              'Указывать достоверную информацию об объекте недвижимости: '
              'адрес, площадь, стоимость, фотографии и описание.',
            ),
            _bulletItem(
              'Не размещать объявления мошеннического характера, не вводить '
              'других пользователей в заблуждение.',
            ),
            _bulletItem(
              'Не публиковать дублирующиеся объявления об одном и том же '
              'объекте.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Все объявления проходят модерацию. Администрация оставляет '
              'за собой право отклонить или удалить объявление без объяснения '
              'причин в случае нарушения правил платформы.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 5. Правила поведения
            _sectionTitle('5. Правила поведения'),
            const SizedBox(height: 8),
            const Text(
              'Пользователь обязуется вести себя корректно при взаимодействии '
              'с другими участниками платформы. Запрещается:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem('Использование ненормативной лексики и оскорблений.'),
            _bulletItem(
              'Рассылка спама и нежелательных сообщений через встроенный чат.',
            ),
            _bulletItem(
              'Попытки обхода механизмов безопасности и модерации.',
            ),
            const SizedBox(height: 24),

            // 6. Интеллектуальная собственность
            _sectionTitle('6. Интеллектуальная собственность'),
            const SizedBox(height: 8),
            const Text(
              'Все материалы платформы EstateHub, включая дизайн, логотипы, '
              'тексты и программный код, являются интеллектуальной '
              'собственностью администрации платформы и защищены '
              'законодательством Российской Федерации.\n\n'
              'Пользователь сохраняет права на контент, размещённый им '
              'на платформе (фотографии, описания), но предоставляет '
              'EstateHub неисключительную лицензию на его использование '
              'в рамках работы сервиса.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 7. Ограничение ответственности
            _sectionTitle('7. Ограничение ответственности'),
            const SizedBox(height: 8),
            const Text(
              'Администрация EstateHub не несёт ответственности за:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem(
              'Достоверность информации, размещённой пользователями '
              'в объявлениях.',
            ),
            _bulletItem(
              'Результаты сделок, заключённых между пользователями '
              'платформы.',
            ),
            _bulletItem(
              'Временную недоступность сервиса по техническим причинам.',
            ),
            _bulletItem(
              'Убытки, понесённые Пользователем в результате использования '
              'или невозможности использования платформы.',
            ),
            const SizedBox(height: 24),

            // 8. Контакты
            _sectionTitle('8. Контакты'),
            const SizedBox(height: 8),
            const Text(
              'По всем вопросам, связанным с настоящим Соглашением, '
              'вы можете обратиться к нам по электронной почте:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'support@estate-hub.ru',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );
}

Widget _bulletItem(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: Colors.black54),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
      ],
    ),
  );
}
