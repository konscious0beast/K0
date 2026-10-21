"""Session tokens (docs/06 §5.10 "Wer stellt das Sitzungs-Token aus?"). The game never holds a key: it trades a
platform session ticket (Steam session ticket, console / mobile equivalent, own shop login [zu prüfen]) for a short
token (≤ 30 min) signed with MOD_BRAIN_TOKEN_SECRET. The token carries a pseudonymous account id (an HMAC of the
platform account — never the platform id in clear text) and the run_ref it is bound to. Without a valid platform
login there is no token, so nobody can burn the budget with an extracted client.

S1 dev: platform "dev" is accepted only with MOD_BRAIN_DEV_MODE=1 and only from Config.dev_hosts (localhost)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from typing import Callable, Protocol


class PlatformVerifier(Protocol):
    def verify(self, platform: str, ticket: str, client_host: str) -> str:
        """The platform account id for a valid ticket, "" otherwise."""
        ...


class DevVerifier:
    """S1 development only: platform "dev" from allowed hosts → one local dev account."""

    def __init__(self, enabled: bool, hosts: tuple[str, ...]) -> None:
        self.enabled = enabled
        self.hosts = hosts

    def verify(self, platform: str, ticket: str, client_host: str) -> str:
        if self.enabled and platform == "dev" and client_host in self.hosts and ticket:
            return "dev:" + ticket[:64]
        return ""


class SteamVerifier:
    """Placeholder: checks a Steam session ticket server-side via the Steam Web API
    (ISteamUserAuth/AuthenticateUserTicket) [zu prüfen]. Not wired up in S0/S1 — refuses everything."""

    def verify(self, platform: str, ticket: str, client_host: str) -> str:
        return ""


class ChainVerifier:
    def __init__(self, *verifiers: PlatformVerifier) -> None:
        self.verifiers = verifiers

    def verify(self, platform: str, ticket: str, client_host: str) -> str:
        for v in self.verifiers:
            acc = v.verify(platform, ticket, client_host)
            if acc:
                return acc
        return ""


def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")


def _unb64(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


class TokenIssuer:
    def __init__(self, secret: str, ttl_sec: int = 1800, clock: Callable[[], float] = time.time) -> None:
        if not secret:
            raise ValueError("MOD_BRAIN_TOKEN_SECRET is required (secret store; dev mode generates one)")
        self._key = secret.encode("utf-8")
        self.ttl = ttl_sec
        self.clock = clock

    def pseudonym(self, platform_account: str) -> str:
        """Stable pseudonymous account id: HMAC(secret, "acc:" + platform account), 16 hex."""
        return hmac.new(self._key, b"acc:" + platform_account.encode("utf-8"), hashlib.sha256).hexdigest()[:16]

    def issue(self, platform_account: str, run_ref: str) -> str:
        payload = {"v": 1, "acc": self.pseudonym(platform_account), "run": run_ref,
                   "exp": int(self.clock()) + self.ttl}
        body = _b64(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8"))
        sig = _b64(hmac.new(self._key, body.encode("ascii"), hashlib.sha256).digest())
        return body + "." + sig

    def verify(self, token: str, run_ref: str) -> dict:
        """The claims of a valid, unexpired token bound to run_ref; {} otherwise."""
        try:
            body, sig = token.split(".", 1)
            want = _b64(hmac.new(self._key, body.encode("ascii"), hashlib.sha256).digest())
            if not hmac.compare_digest(want, sig):
                return {}
            claims = json.loads(_unb64(body))
        except (ValueError, json.JSONDecodeError, UnicodeDecodeError):
            return {}
        if not isinstance(claims, dict) or claims.get("v") != 1:
            return {}
        if int(claims.get("exp", 0)) <= int(self.clock()) or claims.get("run") != run_ref:
            return {}
        return claims
