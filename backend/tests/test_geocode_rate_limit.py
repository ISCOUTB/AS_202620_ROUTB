from app.modules.geocode.application.rate_limit import UserSearchRateLimit


def test_rate_limit_is_per_user_and_allows_30_requests_per_minute():
    limiter = UserSearchRateLimit(limit=30, window_seconds=60)
    for index in range(30):
        assert limiter.allow(10, now=100 + index / 100)

    assert not limiter.allow(10, now=100.5)
    assert limiter.allow(11, now=100.5)
    assert limiter.allow(10, now=160.01)
