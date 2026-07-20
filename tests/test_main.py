# 测试文件，用 pytest 框架跑
# 文件名必须以 test_ 开头，pytest 才会自动发现它


from fastapi.testclient import TestClient

# 从我们的应用里导入 app 对象（就是 main.py 里 app = FastAPI(...) 那个）
# 为什么能 from app.main 导入：因为在项目根目录跑 pytest，根目录在 sys.path 里，
# app 是一个包（目录下有 __init__.py 或者 Python 3.3+ 的命名空间包机制），app.main 就是 app/main.py
from app.main import app

# 把 app 包进 TestClient，之后 client.get("/xxx") 就等于发一个 HTTP 请求
# 为什么不用真起 uvicorn 服务器再 curl 测：
#   1. TestClient 是内存调用，快（毫秒级）
#   2. 不占端口，CI 环境里不用管端口冲突
#   3. 不用等服务器启动完成
client = TestClient(app)


def test_root():
    # 函数名必须以 test_ 开头，pytest 才会把它当测试用例执行
    response = client.get("/")

    # assert 是 Python 关键字，条件为 False 就抛 AssertionError，测试标记为失败
    # 断言状态码 200（HTTP 成功）
    assert response.status_code == 200
    # 断言返回的 JSON 内容和 main.py 里 root() 返回的完全一致
    assert response.json() == {"name": "demo-app", "version": "v1"}


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
