/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/src/room_account_data.dart';
import 'package:test/test.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/room.dart';
import 'package:famedlysdk/src/timeline.dart';
import 'package:famedlysdk/src/sync/event_update.dart';
import 'fake_matrix_api.dart';

void main() {
  /// All Tests related to the MxContent
  group("Timeline", () {
    final String roomID = "!1234:example.com";
    final testTimeStamp = DateTime.now().millisecondsSinceEpoch;
    int updateCount = 0;
    List<int> insertList = [];

    Client client = Client("testclient", debug: true);
    client.httpClient = FakeMatrixApi();

    Room room = Room(
        id: roomID, client: client, prev_batch: "1234", roomAccountData: {});
    Timeline timeline = Timeline(
        room: room,
        events: [],
        onUpdate: () {
          updateCount++;
        },
        onInsert: (int insertID) {
          insertList.add(insertID);
        });

    test("Create", () async {
      await client.checkServer("https://fakeServer.notExisting");
      client.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "1",
            "origin_server_ts": testTimeStamp
          }));

      client.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "2",
            "origin_server_ts": testTimeStamp - 1000
          }));

      expect(timeline.sub != null, true);

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 2);
      expect(insertList, [0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events.length, 2);
      expect(timeline.events[0].eventId, "1");
      expect(timeline.events[0].sender.id, "@alice:example.com");
      expect(timeline.events[0].time.millisecondsSinceEpoch, testTimeStamp);
      expect(timeline.events[0].body, "Testcase");
      expect(
          timeline.events[0].time.millisecondsSinceEpoch >
              timeline.events[1].time.millisecondsSinceEpoch,
          true);
      expect(timeline.events[0].receipts, []);

      room.roomAccountData["m.receipt"] = RoomAccountData.fromJson({
        "type": "m.receipt",
        "content": {
          "@alice:example.com": {
            "event_id": "1",
            "ts": 1436451550453,
          }
        },
        "room_id": roomID,
      }, room);

      await Future.delayed(Duration(milliseconds: 50));

      expect(timeline.events[0].receipts.length, 1);
      expect(timeline.events[0].receipts[0].user.id, "@alice:example.com");

      client.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.redaction",
          content: {
            "type": "m.room.redaction",
            "content": {"reason": "spamming"},
            "sender": "@alice:example.com",
            "redacts": "2",
            "event_id": "3",
            "origin_server_ts": testTimeStamp + 1000
          }));

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 3);
      expect(insertList, [0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events.length, 2);
      expect(timeline.events[1].redacted, true);
    });

    test("Send message", () async {
      await room.sendTextEvent("test", txid: "1234");

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 5);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].eventId, "42");
      expect(timeline.events[0].status, 1);

      client.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "test"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "42",
            "unsigned": {"transaction_id": "1234"},
            "origin_server_ts": DateTime.now().millisecondsSinceEpoch
          }));

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 6);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].eventId, "42");
      expect(timeline.events[0].status, 2);
    });

    test("Send message with error", () async {
      client.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 0,
            "event_id": "abc",
            "origin_server_ts": testTimeStamp
          }));
      await Future.delayed(Duration(milliseconds: 50));
      await room.sendTextEvent("test", txid: "errortxid");
      await Future.delayed(Duration(milliseconds: 50));
      await room.sendTextEvent("test", txid: "errortxid2");
      await Future.delayed(Duration(milliseconds: 50));
      await room.sendTextEvent("test", txid: "errortxid3");
      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 13);
      expect(insertList, [0, 0, 0, 0, 0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].status, -1);
      expect(timeline.events[1].status, -1);
      expect(timeline.events[2].status, -1);
    });

    test("Remove message", () async {
      await timeline.events[0].remove();

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 14);

      expect(insertList, [0, 0, 0, 0, 0, 0, 0]);
      expect(timeline.events.length, 6);
      expect(timeline.events[0].status, -1);
    });

    test("Resend message", () async {
      await timeline.events[0].sendAgain(txid: "1234");

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 17);

      expect(insertList, [0, 0, 0, 0, 0, 0, 0, 0]);
      expect(timeline.events.length, 6);
      expect(timeline.events[0].status, 1);
    });

    test("Request history", () async {
      await room.requestHistory();

      await Future.delayed(Duration(milliseconds: 50));

      expect(updateCount, 20);
      expect(timeline.events.length, 9);
      expect(timeline.events[6].eventId, "1143273582443PhrSn:example.org");
      expect(timeline.events[7].eventId, "2143273582443PhrSn:example.org");
      expect(timeline.events[8].eventId, "3143273582443PhrSn:example.org");
      expect(room.prev_batch, "t47409-4357353_219380_26003_2265");
    });
  });
}
