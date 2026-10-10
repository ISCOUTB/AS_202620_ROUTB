import os
from pathlib import Path
from dotenv import load_dotenv

ENV_PATH = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(dotenv_path=ENV_PATH)


class Settings:
    TESTING: bool = os.getenv("TESTING") == "1"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    DATABASE_URL_TEST: str = os.getenv("DATABASE_URL_TEST", "")
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "")
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
    JWT_EXPIRE_MINUTES: int = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

    # Parámetros espaciales y de matching
    UTB_CAMPUS_LAT: float = float(os.getenv("UTB_CAMPUS_LAT", "10.371078").strip())
    UTB_CAMPUS_LNG: float = float(os.getenv("UTB_CAMPUS_LNG", "-75.466261").strip())
    GEOCODE_BBOX: str = os.getenv("GEOCODE_BBOX", "-75.6,10.35,-75.45,10.5")

    # Geocodificación (Fase 1)
    PHOTON_BASE_URL: str = os.getenv("PHOTON_BASE_URL", "https://photon.komoot.io")
    NOMINATIM_BASE_URL: str = os.getenv("NOMINATIM_BASE_URL", "https://nominatim.openstreetmap.org")
    NOMINATIM_USER_AGENT: str = os.getenv("NOMINATIM_USER_AGENT", "ROUTB/1.0 (contacto@utb.edu.co)")

    # Routing (Fase 1)
    ROUTING_BASE_URL: str = os.getenv("ROUTING_BASE_URL", "https://router.project-osrm.org")

    # Retención de privacidad (días)
    RETENTION_TRIP_DAYS: int = int(os.getenv("RETENTION_TRIP_DAYS", "30"))
    RETENTION_CACHE_DAYS: int = int(os.getenv("RETENTION_CACHE_DAYS", "7"))

    # Parámetros de matching
    MATCHING_RADIUS_M: int = int(os.getenv("MATCHING_RADIUS_M", "800"))
    MATCHING_TIME_WINDOW_MIN: int = int(os.getenv("MATCHING_TIME_WINDOW_MIN", "15"))
    MATCHING_MAX_DETOUR_MIN: int = int(os.getenv("MATCHING_MAX_DETOUR_MIN", "10"))
    MATCHING_W_DETOUR: float = float(os.getenv("MATCHING_W_DETOUR", "0.5"))
    MATCHING_W_WAIT: float = float(os.getenv("MATCHING_W_WAIT", "0.3"))
    MATCHING_W_APPROACH: float = float(os.getenv("MATCHING_W_APPROACH", "0.2"))
    MATCHING_ROUTING_CANDIDATES: int = int(os.getenv("MATCHING_ROUTING_CANDIDATES", "3"))
    MATCHING_MAX_RESULTS: int = int(os.getenv("MATCHING_MAX_RESULTS", "5"))

    @property
    def effective_database_url(self) -> str:
        if self.TESTING:
            if not self.DATABASE_URL_TEST:
                raise RuntimeError(
                    "TESTING=1 requiere definir DATABASE_URL_TEST en backend/.env"
                )
            return self.DATABASE_URL_TEST
        if not self.DATABASE_URL:
            raise RuntimeError("DATABASE_URL no está configurada")
        return self.DATABASE_URL

    # FCM configuration
    FCM_PROJECT_ID: str = os.getenv("FCM_PROJECT_ID", "")
    FCM_SERVICE_ACCOUNT_B64: str = os.getenv("FCM_SERVICE_ACCOUNT_B64", "")

settings = Settings()
