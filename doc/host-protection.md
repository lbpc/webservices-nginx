Защита сайтов
=============

При обработке каждого HTTP запроса происходит проверка наличия содержимого переменной Nginx __$host__ в списке защищенных хостов (переменная $host из документации Nginx: *«в порядке приоритета: имя хоста из строки запроса, или имя хоста из поля "Host" заголовка запроса, или имя сервера, соответствующего запросу»*).
Список хостов хранится в разделяемой памяти объемом 32M. Для каждого хоста определено время его нахождения в списке (TTL).

Если хост обнаружен в списке, выполняется проверка соответствия cookie __"mj_anti_flood"__ MD5-хэшу от строки, полученной конкатенацией IP адреса клиента в формате A.B.C.D, содержимого поля __"Host"__ в заголовке запроса и строки __"Pbyfblf"__. В случае несоответствия значения или отсутствия такой cookie, клиент получает в ответ страницу с установкой cookie средствами JavaScript.

Если хост не обнаружен в списке или его TTL истек, обработка запроса продолжается как обычно.

При добавлении в список новых хостов после достижения лимита размера списка в 32M в первую очередь вытесняются записи с истекшим TTL. Поскольку список хранится в разделяемой памяти, данные в нем устойчивы к перезагрузке конфигурации, *но не к перезапуску master-процесса Nginx*. Управление содержимым списка реализовано через HTTP API.

Все вызовы API представляют собой HTTP запросы с одним из доступных методов: [GET](#get), [PUT](#put) и [DELETE](#delete). На любой другой метод возвращается ответ `405 Not Allowed`. URL path для всех запросов начинается с `/protect`. Тело запросов и ответов передается простым текстом в UTF-8.


Метод GET	{#get}
---------

Проверить наличие одного хоста в списке защищенных или получить весь список.

Имя хоста задается как последний сегмент URL, если он не задан, то возвращается весь список с разделителем "\n".

+------------------------+--------------------------------------------------------------------------------------+
| /protected/example.com | - `200 OK` *TTL* — хост найден в списке и будет аходиться в нем                      |
|                        |   в течение *TTL* секунд                                                             |
|                        | - `404 Not Found` — хост не найден или TTL истекло                                   |
+------------------------+--------------------------------------------------------------------------------------+
| /protected             | - `200 OK` список строк вида "host.name *TTL*, разделенный символом переноса строки. |
|                        |   Список может быть пустым.                                                          |
+------------------------+--------------------------------------------------------------------------------------+

Примеры:

```bash
$ curl -i web15/protected
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:15:38 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

example.com 388
xn--80aswg.xn--p1ai 592
```

```bash
$ curl -i web15/protected/example.com
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:15:53 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

373
```

```bash
$ curl -i web15/protected/nowhere.net
HTTP/1.1 404 Not Found
Server: nginx
Date: Fri, 10 Jul 2020 12:16:03 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```


Метод PUT	{#put}
---------

Добавить хост в список. Опционально указывается TTL нахождения хоста в списке, по умолчанию 600с.

Имя хоста задается как последний сегмент URL. Никакой валидации имени хоста не предусмотрено.

TTL — значение параметра "ttl" в секундах, неотрицательное 64-битное целое.

Любые параметры, кроме "ttl", игнорируются. Установка TTL = 0, TTL > 7200 требует [авторизации](#auth).

+------------------------+---------------------------------------+---------------------------------------+
| путь                   | параметры                             | ответы                                |
+========================+=======================================+=======================================+
| /protected/example.com | - `ttl`: целое число секунд           | - `200 OK` — хост добавлен в список   |
|                        |                                       | - `400 Bad Request` *текст ошибки* —  |
|                        |                                       |    неверный параметр                  |
|                        |                                       | - `401 Unauthorized` — требуется      |
|                        |                                       |    авторизация                        |
+------------------------+---------------------------------------+---------------------------------------+

Примеры:

```bash
$ curl -i -XPUT web15/protected/example.com
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:19:31 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XPUT web15/protected/0010001111100
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:20:56 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XPUT web15/protected/example.com?ttl=300
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:21:51 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

```

```bash
$ curl -i -XPUT web15/protected/example.com?ttl=999999
HTTP/1.1 401 Unauthorized
Server: nginx
Date: Fri, 10 Jul 2020 12:21:58 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

setting ttl above 7200 or 0 requires authorization
```

```bash
$ curl -i -XPUT web15/protected/example.com?ttl=thousand
HTTP/1.1 400 Bad Request
Server: nginx
Date: Fri, 10 Jul 2020 12:34:25 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

ttl must be a number
```

```bash
$ curl -i -XPUT web15/protected/example.com?ttl=6.62607004
HTTP/1.1 400 Bad Request
Server: nginx
Date: Fri, 10 Jul 2020 12:35:24 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close

ttl must be an integer
```


Метод DELETE	{#delete}
------------

Удалить хост из списка. Не требует авторизации, завершается успешно вне зависимости от наличия хоста в списке на момент запроса.

+------------------------+--------------------------------------------------------------------------------+
| /protected/example.com | - `200 OK` [действие](#actions) — IP успешно удален или отсутствовал в таблице |
+------------------------+--------------------------------------------------------------------------------+

Примеры:

```bash
$ curl -i -XDELETE web15/protected/example.com
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:23:51 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding


```

```bash
$ curl -i web15/protected/example.com
HTTP/1.1 404 Not Found
Server: nginx
Date: Fri, 10 Jul 2020 12:23:58 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding

$ curl -i -XDELETE web15/protected/example.com
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 10 Jul 2020 12:24:00 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Connection: close
Vary: Accept-Encoding
```

Авторизация	{#auth}
-----------

Авторизация производится по токену в HTTP-заголовке "Authorization":

```bash
$ curl -H'Authorization: NONOPLEASEIWILLTELLYOUEVERYTHING' \
     -XPUT web15/protected/example.com?ttl=0
```