CREATE OR REPLACE FUNCTION process_buffer(b buffer)
RETURNS VOID AS
$$
DECLARE
_car_id text;
_last_change timestamptz;
_parked boolean;

BEGIN
    SELECT car_id, parked, last_change FROM hub_parking WHERE car_id = ANY(b.proposed_car_ids) INTO _car_id, _parked, _last_change;
    IF NOT FOUND THEN
        --car probably isn't hub car 
        RETURN;
    END IF;

    -- check if last change is more then 15s
    IF _last_change IS NULL OR last_change +'15s'::interval > now() THEN
        RAISE DEBUG 'found car_id: %, parked: %, updating to parked: %', _car_id, _parked, !_parked;       
        UPDATE hub_parking SET parked = !parked, last_change = b.ts WHERE car_id = _car_id;
    END IF;

END;    
$$ LANGUAGE plpgsql;


CREATE FUNCTION buffer_insert()
RETURNS TRIGGER AS
$$
BEGIN
    PERFORM process_buffer(NEW);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER buffer_insert 
AFTER INSERT
ON buffer
FOR EACH ROW EXECUTE PROCEDURE buffer_insert();


CREATE OR REPLACE FUNCTION hub_parking_insert_update_delete()
RETURNS TRIGGER AS
$$
DECLARE
    _park_size int DEFAULT 10;
    _full boolean;
BEGIN
    SELECT count(*) >= _park_size FROM hub_parking WHERE parked INTO _full;
    
    --let's notify semafor server 
    IF _full THEN
        PERFORM pg_notify('semafor','obsazeno');
    ELSE
        PERFORM pg_notify('semafor','volno');
    END IF;

    IF TG_OP IN ('INSERT','UPDATE') THEN
        RETURN NEW;
    ELSE 
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER hub_parking_insert_update_delete
AFTER INSERT OR UPDATE OR DELETE
ON hub_parking
FOR EACH ROW EXECUTE PROCEDURE hub_parking_insert_update_delete();
