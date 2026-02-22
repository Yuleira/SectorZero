-- Cascade-delete player_buildings when their parent territory is deleted.
-- Uses a trigger so the TEXT territory_id column needs no type change.

CREATE OR REPLACE FUNCTION delete_buildings_for_territory()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    DELETE FROM player_buildings WHERE territory_id = OLD.id::TEXT;
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_territory_cascade_delete
    BEFORE DELETE ON territories
    FOR EACH ROW
    EXECUTE FUNCTION delete_buildings_for_territory();
