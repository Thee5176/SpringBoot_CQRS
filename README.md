# SpringBoot_CQRS

## RoadMap
1. Requirement and Function Analysis
2. Scope Management
3. Design and Diagram
4. Development Practice and Planning
5. Development (Trial & Error with new technologies)
6. Documentation (new Topic Learned during Development and Feedback)

## Development Principle
- Follows Top-Down Software Development Approach: UI Design -> DB Design -> Module Design
- Git Best Practice with "[A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/)"

## Install and Run Process
```bash
#1 Prepare directory and clone from github
git clone --recurse-submodules -j2 https://github.com/Thee5176/SpringBoot_CQRS
cd SpringBoot_CQRS

#2 make migration, build process

##2.1 Command Unit: spin up postgres container and set up DB
docker compose up postgres -d --build
cd springboot_cqrs_command
chmod +x mvnw
./mvnw flyway:migrate
./mvnw clean package -DskipTests
cd ..

##2.2 Query Unit:
cd springboot_cqrs_query
chmod +x mvnw
./mvnw clean package -DskipTests
cd ..

#3 Start All Service
docker compose build --no-cache
docker compose up -d
```

## Functionality
1. 

## New Technology Used (Trial & Error)
- Git Flow, Git Pull Request, Git Issues and Git Submodule
    - manage local branch according to best practice branching strategy [GitFlow]
    - review change before merge branch with Git Pull Request [Git Pull Request](https://github.com/pulls?q=is%3Apr+author%3AThee5176+archived%3Afalse+repository%3Bspringboot*)
    - Manage aggregate project that separate each git history [Git Submodule](https://github.com/Thee5176/SpringBoot_CQRS/tree/main)
    - Reference: [Git実践入門](https://gihyo.jp/book/2014/978-4-7741-6366-6)

- Github Workflow
    - set up continuous integration for verify building process
    - [Command Unit Workflow](https://github.com/Thee5176/springboot_cqrs_command/actions/workflows/testrun.yaml)
    - [Query Unit Build Workflow](https://github.com/Thee5176/springboot_cqrs_query/actions/workflows/testrun.yaml)
    - [Deployment Workflow](https://github.com/Thee5176/SpringBoot_CQRS/actions/workflows/testrun.yaml)

- Sourcery.ai - Pull Request Review Service
    - AI-generated change review guideline
    - create code suggestion [Example PR Review Message](https://github.com/Thee5176/springboot_cqrs_command/pull/9#issuecomment-3092684740)
    - source: [Sourcery AI](https://sourcery.ai/)

- Flyway 
    - set up Flyway database migration service in [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L162)
    - manage database version [source/main/resources/db/migrations](https://github.com/Thee5176/springboot_cqrs_command/tree/develop/src/main/resources/db/migration)
    - source: [Spring Doc](https://docs.spring.io/spring-boot/how-to/data-initialization.html#howto.data-initialization.migration-tool.flyway)

- JOOQ
    - Top-Down Development process with JOOQ Codegen
        - Design the Database with dbml language [DB Design Document](https://dbdocs.io/theerapong5176/Springboot_CQRS?view=relationships)
        - Generate DDL script from [dbdiagram.io](https://dbdiagram.io/)
        - Setup JOOQ Codegen dependency with [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L175)
        - source: [JOOQ Document](https://www.jooq.org/doc/latest/manual/code-generation/codegen-execution/codegen-maven/)

- ModelMapper
    - set up ModelMapper in [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L78)
    - config custom DTO [ModelMapperConfig](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/main/java/com/thee5176/ledger_command/Application/config/ModelMapperConfig.java)
    - source: [ModelMapper Document](https://modelmapper.org/getting-started/)
 
- Arrange-Action-Assert Testing Process:
    1. Arrange - Establish testing data
    2. Action - Run the Test subject
    3. Assert - Check the desired behaviour result from test subject
  
      
- Unit Test and Integration Test
  - **Unit test** - check real output of each internal code component with [JUnit](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/test/java/com/thee5176/ledger_command/Application/dto/LedgersEntryTest.java)
  - **Integration test** - check for integration call of other function and mock the output with [Mockito](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/test/java/com/thee5176/ledger_command/Domain/service/LedgerCommandServiceTest.java)
  
- [Docker Merge Compose file](https://github.com/Thee5176/SpringBoot_CQRS/blob/main/compose.yaml)

## New Topic Learned (Meeting & Feedback)
- Microservice vs Monolith Architecture
    - **Comparison Table:**
        | Feature             | Monolith                                       | Microservice                                     |
        |---------------------|------------------------------------------------|--------------------------------------------------|
        | **Performance**     | Potentially faster due to direct in-process calls. | Slower due to network latency between services.  |
        | **Resource**        | Less overhead, single deployment unit.         | Higher overhead, each service needs its own resources. |
        | **Shared Development**| Tightly coupled, harder for large teams to work in parallel. | Loosely coupled, easier for teams to work independently. |
        | **Development Speed** | Initially faster, but slows down as the codebase grows. | Slower to start, but maintains speed as system scales. |

- Usage of UUID/ULID/Integer as DB primary key
    - **Comparison Table:**
        | key_type | bit_count | key_amount      | order     | randomness      |
        |----------|-----------|-----------------|-----------|-----------------|
        | UUID v7  | 128-bit   | ~3.4 x 10^38    | Yes       | High (74 bits)  |
        | UUID v4  | 128-bit   | ~3.4 x 10^38    | No        | High (122 bits) |
        | ULID     | 128-bit   | ~3.4 x 10^38    | Yes       | High (80 bits)  |
        | Integer  | 32-bit    | ~4.3 billion    | Yes       | None            |
    - **Situational Usage:**
        - **Integer/BigInt**: Best for simple, single-database applications where global uniqueness is not required. They are small, fast, and human-readable.
        - **UUID v4**: Use in distributed systems where keys must be globally unique but order is not important. The high randomness prevents guessability. Can cause DB index fragmentation.
        - **ULID/UUID v7**: Ideal for distributed systems requiring globally unique, time-sortable keys. This improves database insert performance by preventing index fragmentation. UUID v7 is the modern IETF standard.
    - **Decision Flowchart:**
        ```mermaid
        graph TD
            A[Start: Choose a Primary Key] --> B{Need globally unique ID?}
            B -- No --> C[Use Integer/BigInt]
            B -- Yes --> D{Need time-sortable keys for performance/ordering?}
            D -- No --> E[Use UUID v4]
            D -- Yes --> F[Use UUID v7 or ULID]
        ```

- Ubitiquous Language and Entity Name Refactoring
    - Reserved word, Software development vocab
    - Tips: Master and Transaction Entity, Use Specific language

- Validation Chain
    - Frontend -> DTO validation -> ... -> Database validation
    - Validate the same logic in different layer might seems redundant but it help ensure the dataflow quality
    - Validate and throw data early on also help minimize the exception throw chain which improve throughput time and overall system load

- Master Data management approach
    - **Enum**
        - Pros: In-memory storage (faster to read versus making query to database), Ensure Concistency (Can't be change from user side)
        - Cons: Static Hardcoded Datastorage (changing requred developer to edit the souce code)

    - **Master Entity (Table)**
        - Pros: Dynamic Datastorage (make change on dataset can be done in user side)
        - Cons: Consistency Issue (data is manipulatable via query)
