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

---
## Run Process
```bash
#1 Prepare directory and clone from github
mkdir ledger_cqrs_unit
cd ledger_cqrs_unit
git clone https://github.com/Thee5176/springboot_cqrs_command springboot_cqrs_command
git clone https://github.com/Thee5176/springboot_cqrs_query springboot_cqrs_query

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
---
## New Technology
- Git Flow and Git Pull Request
    - using "git flow" command line to manage local branch
    - review every feature merge with Git Pull Request
- SonarQube - Code Quality Gate
    - set up PR Review 
- Make migration with Flyway Tools
    - 
- Design Driven Development with JOOQ
    - Set up and Generate entity pojos
- ModelMapper
    - config custom DTO and Entity mapping
    - 
- JUnit Test and Test Coverage
- Docker Merge Build

---
## New Topic Learned
- Microservice vs Monolith Architecture
    - **Comparison Table:**
        | Feature             | Monolith                                       | Microservice                                     |
        |---------------------|------------------------------------------------|--------------------------------------------------|
        | **Performance**     | Potentially faster due to direct in-process calls. | Slower due to network latency between services.  |
        | **Resource**        | Less overhead, single deployment unit.         | Higher overhead, each service needs its own resources. |
        | **Shared Development**| Tightly coupled, harder for large teams to work in parallel. | Loosely coupled, easier for teams to work independently. |
        | **Development Speed** | Initially faster, but slows down as the codebase grows. | Slower to start, but maintains speed as system scales. |
- 
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
          A[Start: Choose a Primary Key] --> B{Need globally unique IDs? (e.g., distributed system)};
          B -- No --> C[Use Integer/BigInt];
          B -- Yes --> D{Need time-sortable keys for performance/ordering?};
          D -- No --> E[Use UUID v4];
          D -- Yes --> F[Use UUID v7 or ULID];
      ```

- Agile vs Waterfall Development Approach

- Project Lifecycle Management

- Ubitiquous Language and Entity Name Refactoring
    - Reserved word, Software development vocab
    - Tips: Master and Transaction Entity, Use Specific language

- Validation Chain
    - Frontend -> DTO validation -> ... -> Database validation
    - Validate the same logic in different layer might seems redundant but it help ensure the dataflow quality
    - Validate and throw data early on also help minimize the exception throw chain which improve throughput time and overall system load

- Master Data management approach
    - Enum - manage dataset with in-memory hardcode

    - Master Entity (Table)

