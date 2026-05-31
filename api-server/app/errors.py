class BusinessError(Exception):
    """业务错误，使用 code/msg 直接映射到前端约定的响应信封。"""

    def __init__(self, code: int, msg: str) -> None:
        self.code = code
        self.msg = msg
        super().__init__(msg)
