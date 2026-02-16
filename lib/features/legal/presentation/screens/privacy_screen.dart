import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Политика конфиденциальности',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Последнее обновление: Февраль 2026',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            const Text(
              'Компания EstateHub (estate-hub.ru) серьёзно относится к защите '
              'конфиденциальности своих пользователей. Настоящая Политика '
              'конфиденциальности описывает, какие данные мы собираем, как мы их '
              'используем и какие меры предпринимаем для их защиты.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 1. Какие данные мы собираем
            _sectionTitle('1. Какие данные мы собираем'),
            const SizedBox(height: 8),
            const Text(
              'При использовании платформы EstateHub мы можем собирать '
              'следующие данные:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem('Номер телефона — для регистрации и входа в аккаунт.'),
            _bulletItem('Имя и фамилия — для отображения в профиле и объявлениях.'),
            _bulletItem(
              'Информация об объявлениях — адрес, описание, фотографии, '
              'стоимость и характеристики объектов недвижимости.',
            ),
            _bulletItem(
              'Данные об использовании — информация о посещённых страницах, '
              'действиях в приложении, типе устройства и версии ОС.',
            ),
            const SizedBox(height: 24),

            // 2. Как мы используем данные
            _sectionTitle('2. Как мы используем данные'),
            const SizedBox(height: 8),
            const Text(
              'Собранные данные используются в следующих целях:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem('Управление аккаунтом и авторизация пользователей.'),
            _bulletItem('Публикация и отображение объявлений о недвижимости.'),
            _bulletItem(
              'Обеспечение коммуникации между пользователями '
              '(встроенный чат, уведомления).',
            ),
            _bulletItem(
              'Улучшение качества сервиса и персонализация опыта '
              'использования.',
            ),
            const SizedBox(height: 24),

            // 3. Передача данных третьим лицам
            _sectionTitle('3. Передача данных третьим лицам'),
            const SizedBox(height: 8),
            const Text(
              'Номер телефона пользователя отображается в объявлении только '
              'в том случае, если пользователь не скрыл его в настройках '
              'профиля.\n\n'
              'Мы не продаём и не передаём персональные данные пользователей '
              'третьим лицам в коммерческих целях. Данные могут быть переданы '
              'только в случаях, предусмотренных законодательством Российской '
              'Федерации.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 4. Защита данных
            _sectionTitle('4. Защита данных'),
            const SizedBox(height: 8),
            const Text(
              'Мы применяем современные технические и организационные меры '
              'для защиты персональных данных от несанкционированного доступа, '
              'изменения, раскрытия или уничтожения. Передача данных '
              'осуществляется по зашифрованным каналам связи.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // 5. Права пользователей
            _sectionTitle('5. Права пользователей'),
            const SizedBox(height: 8),
            const Text(
              'Каждый пользователь имеет право:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            _bulletItem('Получить доступ к своим персональным данным.'),
            _bulletItem(
              'Изменить или обновить информацию в профиле и объявлениях.',
            ),
            _bulletItem(
              'Удалить свой аккаунт и все связанные с ним данные.',
            ),
            _bulletItem(
              'Скрыть номер телефона из публичного доступа в настройках '
              'профиля.',
            ),
            const SizedBox(height: 24),

            // 6. Контакты
            _sectionTitle('6. Контакты'),
            const SizedBox(height: 8),
            const Text(
              'Если у вас есть вопросы или предложения, связанные с настоящей '
              'Политикой конфиденциальности, вы можете связаться с нами '
              'по электронной почте:',
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
