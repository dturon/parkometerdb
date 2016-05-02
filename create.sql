-- camera log
CREATE TABLE buffer(
    ts timestamptz primary key,
    filename text not null,
    proposed_car_ids text[] not null
);

-- hub registred car ID
CREATE TABLE hub_parking(
    car_id text primary key,
    parked boolean not null default false,
    last_change timestamptz
);