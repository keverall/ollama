# API Endpoints

This document provides an overview of the API endpoints available in the Ollama optimized environment.

## Ollama API

Ollama provides a REST API for interacting with language models. By default, the API is available at `http://localhost:11434`.

### Common Endpoints

#### Get Version
```bash
curl http://localhost:11434/api/version
```

#### List Models
```bash
curl http://localhost:11434/api/tags
```

#### Show Model Information
```bash
curl http://localhost:11434/api/show -d '{
  "name": "qwen2.5-coder:32b-gpu"
}'
```

#### Generate Text
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:32b-gpu",
  "prompt": "Explain quantum computing in simple terms",
  "stream": false
}'
```

#### Chat Completion
```bash
curl http://localhost:11434/api/chat -d '{
  "model": "qwen2.5-coder:32b-gpu",
  "messages": [
    {"role": "user", "content": "Explain quantum computing in simple terms"}
  ],
  "stream": false
}'
```

#### Embeddings
```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "The quick brown fox jumps over the lazy dog"
}'
```

#### Copy a Model
```bash
curl -X POST http://localhost:11434/api/copy -d '{
  "source": "qwen2.5-coder:32b-gpu",
  "destination": "qwen2.5-coder:32b:backup"
}'
```

#### Delete a Model
```bash
curl -X DELETE http://localhost:11434/api/delete -d '{
  "name": "qwen2.5-coder:32b:backup"
}'
```

## Qdrant API

Qdrant provides a REST API for vector database operations. By default, the API is available at `http://localhost:6333`.

### Common Endpoints

#### Get Collections
```bash
curl http://localhost:6333/collections
```

#### Create Collection
```bash
curl -X POST http://localhost:6333/collections -d '{
  "collection_name": "ollama_embeddings",
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  }
}'
```

#### Get Collection Info
```bash
curl http://localhost:6333/collections/ollama_embeddings
```

#### Upsert Points (Add/Update Vectors)
```bash
curl -X PUT http://localhost:6333/collections/ollama_embeddings/points -d '{
  "points": [
    {
      "id": 1,
      "vector": [0.1, 0.2, 0.3, ...], // 768 dimensions
      "payload": {
        "text": "Example text",
        "model": "nomic-embed-text:latest"
      }
    }
  ]
}'
```

#### Search Vectors
```bash
curl -X POST http://localhost:6333/collections/ollama_embeddings/points/search -d '{
  "vector": [0.1, 0.2, 0.3, ...], // 768 dimensions
  "limit": 10,
  "with_payload": true
}'
```

#### Delete Points
```bash
curl -X POST http://localhost:6333/collections/ollama_embeddings/points/delete -d '{
  "points": [1, 2, 3]
}'
```

#### Update Collection
```bash
curl -X PUT http://localhost:6333/collections/ollama_embeddings -d '{
  "optimizers_config": {
    "default_segment_number": 2
  }
}'
```

#### Delete Collection
```bash
curl -X DELETE http://localhost:6333/collections/ollama_embeddings
```

## Health Checks

### Ollama Health
```bash
curl -s http://localhost:11434/api/version
```

### Qdrant Health
```bash
curl -s http://localhost:6333/ready
```

## Authentication

By default, both Ollama and Qdrant are configured to run without authentication for local development. 
For production use, consider implementing appropriate security measures such as:
- Reverse proxy with authentication
- Firewall rules to restrict access
- API keys or tokens

## CORS

If you need to access these APIs from a web application running on a different origin, 
you may need to configure CORS settings. For Ollama, this can be done by setting the 
`OLLAMA_ORIGINS` environment variable. For Qdrant, you can use the CORS configuration 
in the Docker Compose file or the Qdrant configuration.

## Rate Limiting

These services do not include built-in rate limiting. If you plan to expose them publicly,
consider implementing rate limiting at the reverse proxy or application level.

## Examples

### Generating Embeddings with Ollama and Storing in Qdrant

1. Generate an embedding using Ollama:
```bash
EMBEDDING=$(curl -s http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "Your text here"
}' | jq -r '.embedding')
```

2. Store the embedding in Qdrant:
```bash
curl -X PUT http://localhost:6333/collections/ollama_embeddings/points -d '{
  "points": [
    {
      "id": $(date +%s),
      "vector": ['$EMBEDDING'],
      "payload": {
        "text": "Your text here",
        "timestamp": "'$(date -Iseconds)'"
      }
    }
  ]
}'
```

### Querying Similar Texts

1. Generate an embedding for your query:
```bash
QUERY_EMBEDDING=$(curl -s http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "Your query text here"
}' | jq -r '.embedding')
```

2. Search for similar vectors in Qdrant:
```bash
curl -X POST http://localhost:6333/collections/ollama_embeddings/points/search -d '{
  "vector": ['$QUERY_EMBEDDING'],
  "limit": 5,
  "with_payload": true
}'
```

---
**Last Updated:** 2026-04-30  
**Version:** 1.0.0
