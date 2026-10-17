-- Invite rewards. A player can redeem one invite code, and only while their account is new.

create table referrals (
    invitee_id  uuid primary key references users (id) on delete cascade,
    inviter_id  uuid        not null references users (id) on delete cascade,
    rewarded    boolean     not null,
    created_at  timestamptz not null default now(),
    check (invitee_id <> inviter_id)
);
create index idx_referrals_inviter on referrals (inviter_id);
