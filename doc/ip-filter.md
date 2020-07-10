IP-фильтр
=========

Все HTTP запросы, которые принимает Nginx, проходят через фильтр IP адресов, реализованный на встроенном Lua. Данные для фильтрации хранятся в разделяемой памяти объемом 32M. Для каждого IP адреса определено время его нахождения в таблице (TTL) и одно из трех возможных действий, закодированных целым числом:

* __0__ — проверить соответствие cookie __"mj_anti_flood"__ MD5-хэшу от строки, полученной конкатенацией IP адреса клиента в формате A.B.C.D, содержимого заголовка __"Host"__ в запросе и строки __"Pbyfblf"__. В случае несоответствия значения или отсутствия такой cookie вернуть в ответ на запрос страницу с установкой cookie средствами JavaScript.
* __1__ — вернуть ответ с кодом состояния HTTP 403.
* __2__ — разорвать соединение с клиентом.

Если записи с IP адресом клиента в таблице не найдено или ее TTL истек, обработка запроса продолжается как обычно. При добавлении в таблицу новых записей после достижения лимита размера таблицы в 32M в первую очередь вытесняются записи с истекшим TTL. Поскольку таблица хранится в разделяемой памяти, данные в ней устойчивы к перезагрузке конфигурации, *но не к перезапуску master-процесса Nginx*. Управление содержимым таблицы реализовано через HTTP API.

Все вызовы API представляют собой HTTP запросы с одним из доступных методов: [GET](#get), [PUT](#put), [POST](#post) и [DELETE](#delete). На любой другой метод возвращается ответ `405 Not Allowed`. URL path для всех запросов начинается с `/ip-filter`. Тело запросов и ответов передается простым текстом в UTF-8.

Действия фильтра в API	{#actions}
----------------------

внутренний код   код API    действие
---------------  ---------  -------------------------------
0                setCookie  проверить или установить cookie
1                return403  вернуть 403
2                connReset  разорвать соединение


Метод GET	{#get}
---------

Получить информацию о содержимом таблицы фильтрации по одному или всем IP адресам.

IP адрес задается как последний сегмент URL в формате 4 октетов, разделенных точкой (A.B.C.D), если он не задан, то возвращается содержимое всей таблицы.

+------------------------+-------------------------------------------------------------------------+
| /ip-filter/IP.ADD.RE.SS| - `200 OK` *TTL* [действие](#actions) — IP найден в таблице и будет     |
|                        |   находиться в ней в течение *TTL* секунд                               |
|                        | - `404 Not Found` — IP не найден, некорректен или TTL истекло           |
+------------------------+-------------------------------------------------------------------------+
| /ip-filter             | - `200 OK` список строк вида "IP.ADD.RE.SS *TTL* [действие](#actions)", |
|                        |   разделенных символом переноса строки.                                 |
|                        |   Список может быть пустым.                                             |
+------------------------+-------------------------------------------------------------------------+

Примеры:

```bash
$ curl -i -XGET web15/ip-filter/61.6.28.13
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 11:36:25 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

setCookie
```

```bash
$ curl -i -XGET web15/ip-filter/8.8.8.8
HTTP/1.1 404 Not Found
Server: nginx
Date: Sat, 29 Dec 2018 11:40:33 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XGET web15/ip-filter
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 11:45:15 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XGET web15/ip-filter
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 11:51:56 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

152.32.140.156 setCookie
177.99.217.233 setCookie
115.68.27.52 setCookie
46.119.126.222 setCookie
185.86.164.106 setCookie
101.109.44.92 setCookie
90.76.108.245 setCookie
175.143.205.185 setCookie
77.68.76.115 setCookie
61.6.28.13 setCookie
94.46.13.110 setCookie
82.166.143.49 setCookie
192.228.245.43 setCookie
199.249.230.68 setCookie
123.30.185.160 return403
```


Метод PUT	{#put}
---------

Добавить в таблицу IP адрес с TTL и [действием фильтра](#actions). Всё, кроме IP, может быть не указано. TTL по умолчанию равно 600с, действие — "setCookie".

IP адрес задается как последний сегмент URL в формате 4 октетов, разделенных точкой (A.B.C.D).

TTL — значение параметра "ttl" в секундах, неотрицательное 64-битное целое.

Действие фильтра — значение параметра "action", строка, см. [действия](#actions).

Любые параметры, кроме "ttl" и "action", игнорируются. Установка TTL = 0, TTL > 7200 и любого действия, кроме "setCookie" требует [авторизации](#auth).

Кроме того, нельзя добавлять в таблицу адрес 127.0.0.1, внешний IP сервера и адрес, с которого отправлен запрос.

+-------------------------+---------------------------------------+---------------------------------------+
| путь                    | параметры                             | ответы                                |
+=========================+=======================================+=======================================+
| /ip-filter/IP.ADD.RE.SS | - `ttl`: целое число секунд           | - `200 OK` — запись успешно создана   |
|                         | - `action`: "setCookie",              | - `400 Bad Request` *текст ошибки* —  |
|                         |           "return403" или "connReset" |    неверный путь или параметры        |
|                         |                                       | - `401 Unauthorized` — требуется      |
|                         |                                       |    авторизация                        |
+-------------------------+---------------------------------------+---------------------------------------+

Примеры:

```bash
$ curl -i -XPUT 'web15/ip-filter/123.30.185.160'
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:06:46 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XPUT 'web15/ip-filter/123.30.185.160?action=return403'
HTTP/1.1 401 Unauthorized
Server: nginx
Date: Sat, 29 Dec 2018 15:07:43 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

'return403' action requires authorization
```

```bash
$ curl -i -XPUT 'web15/ip-filter/123.30.185.160?ttl=5'
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:08:54 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XPUT 'web15/ip-filter/123.30.185.160?ttl=7200&action=setCookie'
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:19:53 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -H'Authorization: SECRET' \
       -XPUT 'web15/ip-filter/123.30.185.160?action=connReset&ttl=0'
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:18:59 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding


```

```bash
$ curl -i -XPUT web15/ip-filter/123.123
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 15:34:07 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

123.123 is not an IP address
```

```bash
$ curl -i -XPUT web15/ip-filter/127.0.0.1
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 15:34:45 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

blocking localhost is not a good idea
```

```bash
$ curl -i -XPUT web15/ip-filter/`dig web15.majordomo.ru +short`
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 15:22:41 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

78.108.80.33 is my own IP!
```

```bash
$ curl -i -XPUT web15/ip-filter/172.16.100.1
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 16:14:22 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

so, you are asking me to block your own address. are you sane?
```

Метод POST	{#post}
----------

Добавить в таблицу один или более IP адресов с TTL и [действиями фильтра](#actions). Записи в таблицу фильтрации передаются *в теле запроса* в виде строк вида "IP.ADD.RE.SS ttl [действие](#actions)". Формат IP адреса и области значений TTL и действий, а также требования авторизации аналогичны методу [PUT](#put). Допустимо не задавать либо действие, либо TTL и действие *одновременно*:

* "IP.ADD.RE.SS ttl [действие](#actions)"
* "IP.ADD.RE.SS ttl"
* "IP.ADD.RE.SS"

Умолчания в обоих случаях также аналогичны методу [PUT](#put).

__Каждая__ строка в теле запроса обязательно заканчивается символом переноса строки ("\\n").

В случае, если хотя бы одна из строк не удовлетворяет требованиям, весь запрос будет отвергнут целиком. В собщении об ошибке указываются номера некорректных строк начиная с 1. Проверка авторизации имеет более низкий приоритет, поэтому если как минимум один из параметров указан неверно *и* запрос требует авторизации, код ответа будет 400, а не 401.

+-------------------------+---------------------------------------+---------------------------------------+
| путь                    | тело запроса                          | ответы                                |
+=========================+=======================================+=======================================+
| /ip-filter              | `IP.ADD.RE.SS\ [ttl[\ action]]\n` \   | - `200 OK` — записи успешно созданы   |
|                         | `IP.ADD.RE.SS\ [ttl[\ action]]\n` \   | - `400 Bad Request` *текст ошибки* —  |
|                         | ...                                   |    неверный путь или параметры        |
|                         |                                       | - `401 Unauthorized` — требуется      |
|                         |                                       |    авторизация                        |
+-------------------------+---------------------------------------+---------------------------------------+

Примеры:

```bash
$ cat <<SNIP | curl -i -XPOST --data-binary @- web15/ip-filter
> 123.30.185.160 600 setCookie
> 134.249.141.24 600
> 46.119.126.222
> 185.234.217.123 600
> 199.249.230.81 600 setCookie
> SNIP
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:26:41 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ cat <<SNIP | curl -i -XPOST --data-binary @- web15/ip-filter
123.30.185.160 600 setCookie
134.249.141.24 600 return403
46.119.126.222 0
185.234.217.123 600
199.249.230.81 600 setCookie
SNIP
HTTP/1.1 401 Unauthorized
Server: nginx
Date: Sat, 29 Dec 2018 15:28:23 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

'return403' action requires authorization in line no. 2: '134.249.141.24 600 return403'
setting ttl above 7200 or 0 requires authorization in line no. 3: '46.119.126.222 0'
```

```bash
$ cat <<SNIP | curl -i -XPOST --data-binary @- web15/ip-filter
123.30.185.160 600 offWithHisHead
134.249.141.24 600 return403
46.119.126.222 0
185.234.217.123 600
199.249.230.81 600 setCookie
SNIP
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 15:33:38 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

unknown action 'offWithHisHead', value must be one of 'setCookie', 'return403' or 'connReset'
'return403' action requires authorization in line no. 2: '134.249.141.24 600 return403'
setting ttl above 7200 or 0 requires authorization in line no. 3: '46.119.126.222 0'
```

Метод DELETE	{#delete}
------------

Удалить IP адрес из таблицы фильтрации. Не требует авторизации, завершается успешно вне зависимости от наличия IP адреса в таблице на момент запроса.

+------------------------+-----------------------------------------------------------+
| /ip-filter/IP.ADD.RE.SS| - `200 OK` — IP успешно удален или отсутствовал в таблице |
|                        | - `400 Bad Request` — IP адрес некорректен                |
+------------------------+-----------------------------------------------------------+

Примеры:

```bash
$ curl web15/ip-filter/134.249.141.24
return403
$ curl -i -XDELETE web15/ip-filter/134.249.141.24
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:38:04 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i web15/ip-filter/134.249.141.24
HTTP/1.1 404 Not Found
Server: nginx
Date: Sat, 29 Dec 2018 15:38:38 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

$ curl -i -XDELETE web15/ip-filter/134.249.141.24
HTTP/1.1 200 OK
Server: nginx
Date: Sat, 29 Dec 2018 15:38:43 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XDELETE web15/ip-filter/all
HTTP/1.1 400 Bad Request
Server: nginx
Date: Sat, 29 Dec 2018 15:39:29 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

all is not an IP address

```

Авторизация	{#auth}
-----------

Авторизация производится по токену в HTTP-заголовке "Authorization":

```bash
curl -H'Authorization: DIDYOUREALLYEXPECTEDTOSEEITHERE?' \
     -XPUT 'web15/ip-filter/123.30.185.160?action=connReset'
```
