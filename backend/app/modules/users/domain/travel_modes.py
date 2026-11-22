class TravelModes:
    """Modalidades de transporte de una identidad; role es el campo histórico."""

    @property
    def driver_enabled(self) -> bool:
        return self.role == "driver" or self.driver_activated_at is not None

    @property
    def active_mode(self) -> str:
        if not self.driver_enabled:
            return "passenger"
        return self.preferred_mode or "driver"
