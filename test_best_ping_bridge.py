"""Offline regressions; never read a real cookie or contact Roblox."""
import tempfile
import unittest
from pathlib import Path

from best_ping_bridge import Catalogue, OccupancyProof, PLACE_ID, atomic_json, read_request


def page(rows, cursor=None):
    return {"data": [{"id": sid, "playing": count, "maxPlayers": 7} for sid, count in rows],
            "nextPageCursor": cursor}


def demand(*excluded):
    return {"requestId": "hop", "excluded": set(excluded)}


class BridgeTests(unittest.TestCase):
    def test_consumed_single_batch_continues_cursor_before_two(self):
        c = Catalogue(100)
        c.add(page([("two", 2), ("one-a", 1)], "page-2"), 100)
        self.assertEqual(c.response(demand(), 100)["servers"][0]["id"], "one-a")
        self.assertEqual(c.response(demand("one-a"), 100)["state"], "scanning")
        self.assertEqual(c.cursor, "page-2")
        c.add(page([("one-b", 1), ("three", 3)]), 115)
        self.assertEqual(c.response(demand("one-a"), 115)["servers"][0]["id"], "one-b")
        self.assertEqual(c.response(demand("one-a", "one-b"), 115)["occupancy"], 2)

    def test_all_occupancies_and_native_order_survive_new_hop(self):
        c = Catalogue(100)
        c.add(page([("six", 6), ("two-a", 2), ("one", 1), ("four", 4),
                    ("two-b", 2), ("five", 5), ("three", 3)]), 100)
        visited = []
        for count in range(1, 7):
            result = c.response(demand(*visited), 101)
            self.assertEqual(result["occupancy"], count)
            if count == 2:
                self.assertEqual([r["id"] for r in result["servers"]], ["two-a", "two-b"])
            visited.extend(row["id"] for row in result["servers"])
        self.assertEqual(c.response(demand(*visited), 101)["servers"], [])

    def test_stale_complete_scan_cannot_advance_to_two(self):
        c = Catalogue(100)
        c.add(page([("two", 2)]), 290)
        self.assertFalse(c.response(demand(), 290)["complete"])
        self.assertEqual(c.response(demand(), 290)["state"], "scanning")

    def test_native_dedup_preserves_first_rank_and_updates_occupancy(self):
        c = Catalogue(100)
        c.add(page([("a", 2), ("b", 1)], "later"), 100)
        c.add(page([("a", 1), ("c", 1)]), 110)
        self.assertEqual([r["id"] for r in c.response(demand(), 110)["servers"]], ["a", "b", "c"])
        self.assertEqual(c.rows["a"]["nativeRank"], 1)

    def test_repeated_cursor_and_http_error_do_not_allow_higher_group(self):
        c = Catalogue(100)
        c.add(page([("two", 2)], "same"), 100)
        self.assertFalse(c.add(page([("three", 3)], "same"), 115))
        self.assertFalse(c.complete)
        self.assertEqual(c.response(demand(), 115)["state"], "error")
        c.error = "rate_limited"
        self.assertEqual(c.response(demand(), 115)["servers"], [])

    def test_filters_stale_full_and_invalid_and_has_no_cookie_fields(self):
        c = Catalogue(100)
        c.add(page([("empty", 0), ("full", 7), ("fraction", 1.5), ("one", 1)]), 100)
        self.assertEqual(list(c.rows), ["one"])
        result = c.response(demand(), 281)
        self.assertEqual(result["servers"], [])
        self.assertNotIn("cursor", result)
        self.assertNotIn("cookie", result)

    def test_file_exchange_rejects_stale_wrong_place_and_bad_request(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "request.json"
            valid = {"placeId": PLACE_ID, "requestId": "job", "requestedAt": 100, "excluded": ["a"]}
            atomic_json(path, valid)
            self.assertEqual(read_request(path, 100)["excluded"], {"a"})
            self.assertIsNone(read_request(path, 221))
            valid["placeId"] = 123
            atomic_json(path, valid)
            self.assertIsNone(read_request(path, 100))
            path.write_text("{")
            self.assertIsNone(read_request(path, 100))

    def test_ascending_proof_allows_two_without_full_latency_stream(self):
        req = demand("visited-one")
        proof = OccupancyProof(req, 100)
        self.assertTrue(proof.add(page([("visited-one", 1)], "later"), 100))
        self.assertFalse(proof.valid(req, 100))
        self.assertTrue(proof.add(page([("two", 2), ("three", 3)]), 115))
        self.assertEqual(proof.lowest, 2)
        c = Catalogue(100)
        c.add(page([("three", 3), ("two", 2)], "native-more"), 115)
        result = c.response(req, 115, proof)
        self.assertFalse(result["complete"])
        self.assertEqual(result["state"], "ready")
        self.assertEqual(result["occupancy"], 2)

    def test_occupancy_proof_expires_and_is_invalid_after_next_hop(self):
        req = demand("one")
        proof = OccupancyProof(req, 100)
        proof.add(page([("two", 2)]), 100)
        self.assertTrue(proof.valid(req, 110))
        self.assertFalse(proof.valid(req, 191))
        self.assertFalse(proof.valid(demand("one", "two"), 110))

    def test_unsorted_repeated_and_empty_occupancy_pages_cannot_invent_proof(self):
        unsorted = OccupancyProof(demand(), 100)
        self.assertFalse(unsorted.add(page([("two", 2), ("one", 1)]), 100))
        self.assertFalse(unsorted.valid(demand(), 100))
        req = demand("two", "one")
        proof = OccupancyProof(req, 100)
        self.assertFalse(proof.add(page([("two", 2), ("one", 1)]), 100))
        proof = OccupancyProof(req, 100)
        self.assertTrue(proof.add(page([("one", 1)], "same"), 100))
        self.assertFalse(proof.add(page([("two", 2)], "same"), 115))
        self.assertFalse(proof.valid(req, 115))
        proof = OccupancyProof(req, 100)
        proof.add(page([]), 100)
        self.assertFalse(proof.valid(req, 100))


if __name__ == "__main__":
    unittest.main()
