Run OPA locally with Docker
---------------------------
docker run --rm -p 8181:8181 -v "$(pwd)/opa:/opa" openpolicyagent/opa:latest run --server --addr 0.0.0.0:8181 /opa/policy.rego


Start the Simple API Server
---------------------------
cd OpaDotNetDemo
dotnet run


Call the API Server for allowed case
--------------------------------------

curl -i http://localhost:5103/authorize -H "Content-Type: application/json" -d '{ "user": { "role": "developer", "department": "IT" },  "action": "read",  "resource": "docs/123" }'

Result
=============
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: Fri, 13 Feb 2026 21:37:55 GMT
Server: Kestrel
Transfer-Encoding: chunked

{"allowed":true}


Call the API Server for denied case
--------------------------------------

curl -i http://localhost:5103/authorize -H "Content-Type: application/json" -d '{ "user": { "role": "developer", "department": "HR" },  "action": "delete",  "resource": "docs/123" }'

Result
=============
HTTP/1.1 403 Forbidden
Content-Type: application/json; charset=utf-8
Date: Fri, 13 Feb 2026 21:35:13 GMT
Server: Kestrel
Transfer-Encoding: chunked

{"allowed":false,"reasons":["Denied: role=developer dept=HR action=delete resource=docs/123"]}
