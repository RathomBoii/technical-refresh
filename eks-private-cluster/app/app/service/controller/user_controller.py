from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, field_validator

from service.repository.connection import get_conn
from service.repository.postgres_user_repository import PostgresUserRepository
from service.usecase.delete_user import DeleteUserUseCase
from service.usecase.get_user_by_id import GetUserByIdUseCase
from service.usecase.list_users import ListUsersUseCase
from service.usecase.register_user import RegisterUserUseCase

router = APIRouter(prefix="/users", tags=["users"])


class CreateUserRequest(BaseModel):
    username: str
    email: EmailStr
    full_name: str

    @field_validator("username")
    @classmethod
    def username_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("username must not be blank")
        return v.strip()

    @field_validator("full_name")
    @classmethod
    def full_name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("full_name must not be blank")
        return v.strip()


@router.get("")
def list_users(conn: Any = Depends(get_conn)):
    users = ListUsersUseCase(PostgresUserRepository(conn)).execute()
    return [u.to_dict() for u in users]


@router.post("", status_code=201)
def register_user(body: CreateUserRequest, conn: Any = Depends(get_conn)):
    try:
        user = RegisterUserUseCase(PostgresUserRepository(conn)).execute(
            username=body.username,
            email=body.email,
            full_name=body.full_name,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return user.to_dict()


@router.get("/{user_id}")
def get_user(user_id: int, conn: Any = Depends(get_conn)):
    user = GetUserByIdUseCase(PostgresUserRepository(conn)).execute(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return user.to_dict()


@router.delete("/{user_id}", status_code=204)
def delete_user(user_id: int, conn: Any = Depends(get_conn)):
    deleted = DeleteUserUseCase(PostgresUserRepository(conn)).execute(user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
