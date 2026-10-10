"""Session tokens only against (mocked) platform authentication; dev tickets only in dev mode from localhost;
pseudonymous accounts; forged / expired / foreign-run tokens are refused."""

from __future__ import annotations

import pytest

from mod_brain.auth import ChainVerifier, DevVerifier, SteamVerifier, TokenIssuer


class FakeSteam:
    def verify(self, platform: str, ticket: str, client_host: str) -> str:
        return "steam:76561198000000001" if platform == "steam" and ticket == "valid-ticket" else ""


def test_token_requires_platform_auth():
    v = ChainVerifier(DevVerifier(False, ("127.0.0.1",)), FakeSteam())
    assert v.verify("steam", "valid-ticket", "203.0.113.5") == "steam:76561198000000001"
    assert v.verify("steam", "forged", "203.0.113.5") == ""
    assert v.verify("dev", "local-dev", "127.0.0.1") == "", "dev tickets only in dev mode"
    assert SteamVerifier().verify("steam", "valid-ticket", "x") == "", "not wired up in S0/S1"


def test_dev_mode_only_from_allowed_hosts():
    v = DevVerifier(True, ("127.0.0.1", "::1"))
    assert v.verify("dev", "local-dev", "127.0.0.1") == "dev:local-dev"
    assert v.verify("dev", "local-dev", "198.51.100.7") == ""


def test_token_round_trip_and_refusals():
    now = [1_000_000.0]
    issuer = TokenIssuer("secret-a", ttl_sec=1800, clock=lambda: now[0])
    tok = issuer.issue("steam:76561198000000001", "rr_0123456789abcdef")
    claims = issuer.verify(tok, "rr_0123456789abcdef")
    assert claims["run"] == "rr_0123456789abcdef"
    assert "76561198000000001" not in tok and "76561198000000001" not in claims["acc"], "pseudonym only"
    assert claims["acc"] == issuer.pseudonym("steam:76561198000000001"), "stable pseudonym"
    assert issuer.verify(tok, "rr_ffffffffffffffff") == {}, "bound to its run"
    assert TokenIssuer("secret-b").verify(tok, "rr_0123456789abcdef") == {}, "wrong secret"
    body, sig = tok.split(".")
    assert issuer.verify(body + "." + sig[::-1], "rr_0123456789abcdef") == {}, "forged signature"
    assert issuer.verify("garbage", "rr_0123456789abcdef") == {}
    now[0] += 1801
    assert issuer.verify(tok, "rr_0123456789abcdef") == {}, "expired after 30 min"


def test_secret_is_required():
    with pytest.raises(ValueError):
        TokenIssuer("")
