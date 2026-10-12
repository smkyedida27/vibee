package com.puzzlehub.identity;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.security.SecureRandom;
import java.sql.Time;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.Optional;
import java.util.UUID;

@Repository
public class UserRepository {

    private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    static final RowMapper<User> MAPPER = (rs, i) -> {
        Time reminder = rs.getTime("reminder_time");
        return new User(rs.getObject("id", UUID.class), rs.getString("firebase_uid"), rs.getString("display_name"),
                rs.getInt("avatar_id"), rs.getString("country"), rs.getString("locale"), rs.getString("timezone"),
                reminder == null ? null : reminder.toLocalTime(), rs.getBoolean("notifications_enabled"),
                rs.getString("friend_code"), Arrays.asList(rs.getString("roles").split(",")),
                rs.getTimestamp("created_at").toInstant());
    };

    private final JdbcClient jdbc;

    public UserRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public User createGuest(String deviceId, String firebaseUid) {
        UUID id = UUID.randomUUID();
        String name = "Player" + (1000 + RANDOM.nextInt(9000));
        for (int attempt = 0; ; attempt++) {
            String code = friendCode();
            int inserted = jdbc.sql("""
                    insert into users (id, firebase_uid, device_id, display_name, avatar_id, friend_code)
                    values (:id, :fuid, :device, :name, :avatar, :code)
                    on conflict (friend_code) do nothing""")
                    .param("id", id).param("fuid", firebaseUid).param("device", deviceId).param("name", name)
                    .param("avatar", RANDOM.nextInt(16)).param("code", code)
                    .update();
            if (inserted == 1) return findById(id).orElseThrow();
            if (attempt > 5) throw new IllegalStateException("Could not allocate a friend code");
        }
    }

    public Optional<User> findById(UUID id) {
        return jdbc.sql("select * from users where id = :id").param("id", id).query(MAPPER).optional();
    }

    public Optional<User> findByFirebaseUid(String uid) {
        return jdbc.sql("select * from users where firebase_uid = :uid").param("uid", uid).query(MAPPER).optional();
    }

    public Optional<User> findByFriendCode(String code) {
        return jdbc.sql("select * from users where friend_code = :code").param("code", code).query(MAPPER).optional();
    }

    public boolean exists(UUID id) {
        return jdbc.sql("select exists(select 1 from users where id = :id)").param("id", id).query(Boolean.class).single();
    }

    public void linkFirebase(UUID id, String uid) {
        jdbc.sql("update users set firebase_uid = :uid where id = :id").param("uid", uid).param("id", id).update();
    }

    public void updatePreferences(UUID id, String displayName, Integer avatarId, String country, String locale,
                                  String timezone, LocalTime reminderTime, Boolean notificationsEnabled) {
        jdbc.sql("""
                update users set
                  display_name = coalesce(:name, display_name),
                  avatar_id = coalesce(:avatar, avatar_id),
                  country = coalesce(:country, country),
                  locale = coalesce(:locale, locale),
                  timezone = coalesce(:tz, timezone),
                  reminder_time = coalesce(:reminder, reminder_time),
                  notifications_enabled = coalesce(:notif, notifications_enabled)
                where id = :id""")
                .param("name", displayName).param("avatar", avatarId).param("country", country)
                .param("locale", locale).param("tz", timezone)
                .param("reminder", reminderTime == null ? null : Time.valueOf(reminderTime), java.sql.Types.TIME)
                .param("notif", notificationsEnabled).param("id", id)
                .update();
    }

    public void delete(UUID id) {
        jdbc.sql("delete from users where id = :id").param("id", id).update();
    }

    static String friendCode() {
        StringBuilder sb = new StringBuilder(8);
        for (int i = 0; i < 8; i++) sb.append(CODE_ALPHABET.charAt(RANDOM.nextInt(CODE_ALPHABET.length())));
        return sb.toString();
    }
}
