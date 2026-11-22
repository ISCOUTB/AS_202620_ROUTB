from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, StringConstraints


class SupportReportCreate(BaseModel):
    submission_id: UUID
    category: Literal["trip", "reservation", "driver", "app"]
    description: Annotated[str, StringConstraints(strip_whitespace=True, min_length=10, max_length=2000)]


class SupportReportReceipt(BaseModel):
    id: int
