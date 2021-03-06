/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
 */

import '../matrix.dart';

import 'event.dart';
import 'room.dart';

/// Represents a Matrix User which may be a participant in a Matrix Room.
class User extends Event {
  factory User(
    String? id, {
    String? membership,
    String? displayName,
    String? avatarUrl,
    Room? room,
  }) {
    final content = <String, String>{};
    if (membership != null) content['membership'] = membership;
    if (displayName != null) content['displayname'] = displayName;
    if (avatarUrl != null) content['avatar_url'] = avatarUrl;
    return User.fromState(
      stateKey: id,
      content: content,
      typeKey: EventTypes.RoomMember,
      roomId: room?.id,
      room: room,
      originServerTs: DateTime.now(), 
      senderId: '', 
      eventId: '',
    );
  }

  User.fromState(
      {dynamic prevContent,
      String? stateKey,
      required dynamic content,
      required String typeKey,
      required String eventId,
      String? roomId,
      required String senderId,
      required DateTime originServerTs,
      dynamic unsigned,
      Room? room})
      : super(
            stateKey: stateKey,
            prevContent: prevContent,
            content: content,
            type: typeKey,
            eventId: eventId,
            roomId: roomId,
            senderId: senderId,
            originServerTs: originServerTs,
            unsigned: unsigned,
            room: room);

  /// The full qualified Matrix ID in the format @username:server.abc.
  String? get id => stateKey;

  /// The displayname of the user if the user has set one.
  String? get displayName =>
      content != null && content.containsKey('displayname')
          ? content['displayname']
          : (prevContent != null ? prevContent!['displayname'] : null);

  /// Returns the power level of this user.
  int? get powerLevel => room?.getPowerLevelByUserId(id);

  /// The membership status of the user. One of:
  /// join
  /// invite
  /// leave
  /// ban
  Membership get membership => Membership.values.firstWhere((e) {
        if (content['membership'] != null) {
          return e.toString() == 'Membership.' + content['membership'];
        }
        return false;
      }, orElse: () => Membership.join);

  /// The avatar if the user has one.
  Uri? get avatarUrl => content != null && content.containsKey('avatar_url')
      ? (content['avatar_url'] is String
          ? Uri.tryParse(content['avatar_url'])
          : null)
      : (prevContent != null && prevContent!['avatar_url'] is String
          ? Uri.tryParse(prevContent!['avatar_url'])
          : null);

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname. If [formatLocalpart] is true, then the localpart will
  /// be formatted in the way, that all "_" characters are becomming white spaces and
  /// the first character of each word becomes uppercase.
  /// If [mxidLocalPartFallback] is true, then the local part of the mxid will be shown
  /// if there is no other displayname available. If not then this will return "Unknown user".
  String? calcDisplayname({
    bool? formatLocalpart,
    bool? mxidLocalPartFallback,
  }) {
    formatLocalpart ??= room?.client?.formatLocalpart ?? true;
    mxidLocalPartFallback ??= room?.client?.mxidLocalPartFallback ?? true;
    if (displayName?.isNotEmpty ?? false) {
      return displayName;
    }
    if (stateKey != null && mxidLocalPartFallback) {
      if (!formatLocalpart) {
        return stateKey!.localpart;
      }
      final words = stateKey!.localpart!.replaceAll('_', ' ').split(' ');
      for (var i = 0; i < words.length; i++) {
        if (words[i].isNotEmpty) {
          words[i] = words[i][0].toUpperCase() + words[i].substring(1);
        }
      }
      return words.join(' ');
    }
    return 'Unknown user';
  }

  /// Call the Matrix API to kick this user from this room.
  Future<void> kick() => room!.kick(id!);

  /// Call the Matrix API to ban this user from this room.
  Future<void> ban() => room!.ban(id!);

  /// Call the Matrix API to unban this banned user from this room.
  Future<void> unban() => room!.unban(id!);

  /// Call the Matrix API to change the power level of this user.
  Future<void> setPower(int power) => room!.setPower(id, power);

  /// Returns an existing direct chat ID with this user or creates a new one.
  /// Returns null on error.
  Future<String> startDirectChat() => room!.client!.startDirectChat(id);

  /// The newest presence of this user if there is any and null if not.
  Presence? get presence => room!.client!.presences[id!];

  /// Whether the client is able to ban/unban this user.
  bool get canBan => room!.canBan && powerLevel! < room!.ownPowerLevel!;

  /// Whether the client is able to kick this user.
  bool get canKick =>
      [Membership.join, Membership.invite].contains(membership) &&
      room!.canKick &&
      powerLevel! < room!.ownPowerLevel!;

  /// Whether the client is allowed to change the power level of this user.
  /// Please be aware that you can only set the power level to at least your own!
  bool get canChangePowerLevel =>
      room!.canChangePowerLevel && powerLevel! < room!.ownPowerLevel!;

  @override
  bool operator ==(dynamic other) => (other is User &&
      other.id == id &&
      other.room == room &&
      other.membership == membership);

  /// Get the mention text to use in a plain text body to mention this specific user
  /// in this specific room
  String? get mention {
    // if the displayname has [ or ] or : we can't build our more fancy stuff, so fall back to the id
    // [] is used for the delimitors
    // If we allowed : we could get collissions with the mxid fallbacks
    if ((displayName?.isEmpty ?? true) ||
        {'[', ']', ':'}.any((c) => displayName!.contains(c))) {
      return id;
    }

    var identifier = '@';
    // if we have non-word characters we need to surround with []
    if (!RegExp(r'^\w+$').hasMatch(displayName!)) {
      identifier += '[$displayName]';
    } else {
      identifier += displayName!;
    }

    // get all the users with the same display name
    final allUsersWithSameDisplayname = room!.getParticipants();
    allUsersWithSameDisplayname.removeWhere((user) =>
        user.id == id ||
        (user.displayName?.isEmpty ?? true) ||
        user.displayName != displayName);
    if (allUsersWithSameDisplayname.isEmpty) {
      return identifier;
    }
    // ok, we have multiple users with the same display name....time to calculate a hash
    final hashes = allUsersWithSameDisplayname.map((u) => _hash(u.id!));
    final ourHash = _hash(id!);
    // hash collission...just return our own mxid again
    if (hashes.contains(ourHash)) {
      return id;
    }
    return '$identifier#$ourHash';
  }
}

String _hash(String s) {
  var number = 0;
  for (var i = 0; i < s.length; i++) {
    number += s.codeUnitAt(i);
  }
  return (number % 10000).toString();
}
