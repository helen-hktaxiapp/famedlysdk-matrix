/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

import 'dart:async';

import 'package:matrix/matrix.dart';

import 'package:test/test.dart';
import 'fake_database.dart';

void main() {
  group('Databse', () {
    Logs().level = Level.error;
    int? clientId = -1;
    final room = Room(id: '!room:blubb');
    test('setupDatabase', () async {
      final database = await getDatabase(null);
      clientId = await (database.insertClient(
          'testclient',
          'https://example.org',
          'blubb',
          '@test:example.org',
          '',
          '',
          '',
          '') as FutureOr<int?>);
    });
    test('storeEventUpdate', () async {
      final database = await getDatabase(null);
      // store a simple update
      var update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': <String, dynamic>{'blah': 'blubb'},
          'event_id': '\$event-1',
          'sender': '@blah:blubb',
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      var event = await (database.getEventById(clientId!, '\$event-1', room) as FutureOr<Event>);
      expect(event.eventId, '\$event-1');

      // insert a transaction id
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': <String, dynamic>{'blah': 'blubb'},
          'event_id': 'transaction-1',
          'sender': '@blah:blubb',
          'status': 0,
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, 'transaction-1', room) as FutureOr<Event>);
      expect(event.eventId, 'transaction-1');
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': <String, dynamic>{'blah': 'blubb'},
          'event_id': '\$event-2',
          'sender': '@blah:blubb',
          'unsigned': <String, dynamic>{
            'transaction_id': 'transaction-1',
          },
          'status': 1,
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, 'transaction-1', room) as FutureOr<Event>);
      expect(event, null);
      event = await (database.getEventById(clientId!, '\$event-2', room) as FutureOr<Event>);

      // insert a transaction id if the event id for it already exists
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': {'blah': 'blubb'},
          'event_id': '\$event-3',
          'sender': '@blah:blubb',
          'status': 0,
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, '\$event-3', room) as FutureOr<Event>);
      expect(event.eventId, '\$event-3');
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': {'blah': 'blubb'},
          'event_id': '\$event-3',
          'sender': '@blah:blubb',
          'status': 1,
          'unsigned': <String, dynamic>{
            'transaction_id': 'transaction-2',
          },
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, '\$event-3', room) as FutureOr<Event>);
      expect(event.eventId, '\$event-3');
      expect(event.status, 1);
      event = await (database.getEventById(clientId!, 'transaction-2', room) as FutureOr<Event>);
      expect(event, null);

      // insert transaction id and not update status
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': {'blah': 'blubb'},
          'event_id': '\$event-4',
          'sender': '@blah:blubb',
          'status': 2,
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, '\$event-4', room) as FutureOr<Event>);
      expect(event.eventId, '\$event-4');
      update = EventUpdate(
        type: EventUpdateType.timeline,
        roomID: room.id,
        content: {
          'type': 'm.room.message',
          'origin_server_ts': 100,
          'content': {'blah': 'blubb'},
          'event_id': '\$event-4',
          'sender': '@blah:blubb',
          'status': 1,
          'unsigned': <String, dynamic>{
            'transaction_id': 'transaction-3',
          },
        },
        sortOrder: 0.0,
      );
      await database.storeEventUpdate(clientId!, update);
      event = await (database.getEventById(clientId!, '\$event-4', room) as FutureOr<Event>);
      expect(event.eventId, '\$event-4');
      expect(event.status, 2);
      event = await (database.getEventById(clientId!, 'transaction-3', room) as FutureOr<Event>);
      expect(event, null);
    });
  });
}
