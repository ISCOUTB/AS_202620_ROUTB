"""Límite de búsquedas por usuario para el proceso de la API."""

from __future__ import annotations

from collections import defaultdict, deque
import threading
import time


class UserSearchRateLimit:
    def __init__(self, limit: int = 30, window_seconds: float = 60.0) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._requests: dict[int, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._last_sweep = 0.0

    def allow(self, user_id: int, now: float | None = None) -> bool:
        current = time.monotonic() if now is None else now
        cutoff = current - self.window_seconds
        with self._lock:
            if current - self._last_sweep >= self.window_seconds:
                for tracked_user, history in tuple(self._requests.items()):
                    while history and history[0] <= cutoff:
                        history.popleft()
                    if not history:
                        del self._requests[tracked_user]
                self._last_sweep = current
            requests = self._requests[user_id]
            while requests and requests[0] <= cutoff:
                requests.popleft()
            if len(requests) >= self.limit:
                return False
            requests.append(current)
            return True


geocode_search_rate_limit = UserSearchRateLimit()
