import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    TESTING: bool = os.getenv("TESTING") == "1"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    DATABASE_URL_TEST: str = os.getenv("DATABASE_URL_TEST", "")
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "")
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
    JWT_EXPIRE_MINUTES: int = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

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


settings = Settings()
