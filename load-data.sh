#!/bin/bash
echo "Waiting for Neo4j to be ready..."
until docker exec neo4j-local cypher-shell -u neo4j -p localpassword "RETURN 1" > /dev/null 2>&1; do
  sleep 2
done
echo "Neo4j is ready. Loading data..."
docker exec -i neo4j-local cypher-shell -u neo4j -p localpassword < neo4j/init/seed.cypher
echo "Done! Open http://localhost:7474 to explore."
