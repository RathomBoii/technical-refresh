from __future__ import annotations

from abc import ABC, abstractmethod

from service.entity.oil_price import OilPrice
from service.entity.user import User


class UserRepositoryPort(ABC):
    @abstractmethod
    def save(self, user: User) -> User: ...

    @abstractmethod
    def find_all(self) -> list[User]: ...

    @abstractmethod
    def find_by_id(self, user_id: int) -> User | None: ...

    @abstractmethod
    def delete(self, user_id: int) -> bool: ...


class OilPriceRepositoryPort(ABC):
    @abstractmethod
    def init_schema(self) -> None: ...

    @abstractmethod
    def seed_prices(self) -> None: ...

    @abstractmethod
    def save_prices(self, prices: list[OilPrice]) -> None: ...

    @abstractmethod
    def find_latest(self) -> list[OilPrice]: ...

    @abstractmethod
    def find_history(self, oil_type: str, hours: int) -> list[OilPrice]: ...


class HealthRepositoryPort(ABC):
    @abstractmethod
    def ping(self) -> dict: ...
