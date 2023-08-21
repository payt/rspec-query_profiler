# rspec-query_profiler

Tracks how many database queries it takes to complete an example, separated in queries used by the code under test and queries used by the test setup.

# Usage

```console
PROFILE=1 rspec spec/users/destroy_spec.rb

# app: 2, test: 1
```

When you want all queries triggered by the code:

```console
PROFILE=2 rspec spec/users/destroy_spec.rb

# app: 2
#   User Load SELECT "users".* FROM "users" WHERE "users"."id" = $1 LIMIT $2 [15, 1]
#   User Destroy DELETE FROM "users" WHERE "users"."id" = $1 [15]

# test: 1
```

And all queries triggered by the test setup:

```console
PROFILE=3 rspec spec/users/destroy_spec.rb

# app: 2
#   User Load SELECT "users".* FROM "users" WHERE "users"."id" = $1 LIMIT $2 [15, 1]
#   User Destroy DELETE FROM "users" WHERE "users"."id" = $1 [15]

# test: 1
#   User Create INSERT INTO "users" ("email", "password") VALUES ($1, $2) RETURNING "id" ["test@example.com", "9be35b416ad44c24de8d7fa434ab5d5f"]
```

### Known limitations
- When using Spring you need to stop it before a change in the PROFILE environment variable is picked up.
- It treats the `subject` as something special. RSpec doesn't care if you use either `let` or `subject` in your specs, this gem does. This gem expects exactly one `subject` per example.
- It does not log queries that are triggered during the following callbacks: `suite`, `all`, `context`. These callbacks can span multiple examples, so the queries they trigger cannot unambigiously get assigned to individuel examples (without duplication). They could be logged separatly although these callbacks will probably not trigger a lot of queries in practise.

### Todo
- Create a diffable log of all queries which can be checked into the repo to be able to track performance degredation.
    - The CI could check if the actual number of triggered queries differs from the list checked into the repo.
    - This would force the list to be updated in the repo and makes it visible to reviewers whenever the counts get changed.
    - On the CI the queries triggered by the test setup itself are not relevant.
    - During local testruns the query counts should always be updated automatically so these changes can be checked in.
- It should be clearly visible in the console which queries are executed more than once per example. Makes it easier to track down N+1 queries.
