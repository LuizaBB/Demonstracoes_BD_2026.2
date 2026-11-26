// =====================================================================
// 01 - CONSULTAS (Yelp no Neo4j)
// Modelo usado (importação manual): (:User)-[:REVIEWED]->(:Business)
// Substituir por IDs reais (extraídos da preparação ou consultas manuais)
// Para mostrar o plano de execução, escrever PROFILE antes do início de cada comando. Exemplo:
// PROFILE
// MATCH (...) resto do código
// =====================================================================

// Verificar o que um usuário avaliou (1 salto a partir da âncora)
//  Formato de grafo e tabela
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})-[r:REVIEWED]->(b:Business)
RETURN u, r, b
ORDER BY r.stars DESC, b.name
LIMIT 10;

// Consultar quais usuários avaliaram os mesmo estabelecimentos que o âncora (2 saltos a partir da âncora)
//  Padrão: usuário -> negócio <- outro usuário 
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})-[:REVIEWED]->(b:Business)<-[:REVIEWED]-(outro:User)
WHERE outro <> u
WITH u, outro, count(DISTINCT b) AS negocios_em_comum
ORDER BY negocios_em_comum DESC, outro.name
LIMIT 3
MATCH p = (u)-[:REVIEWED]->(:Business)<-[:REVIEWED]-(outro)
RETURN p,
       outro.id   AS id_outro_usuario,
       outro.name AS outro_usuario,
       negocios_em_comum;

// Consultar os estabelecimentos bem avaliados (nota 4+) avaliados por usuários com mesmo gosto do âncora
//   (mesmos lugares bem avaliados) que o âncora ainda não avaliou
// Busca as 3 melhores opções (3 mais bem avaliadas)
// 3 saltos a partir da âncora e exclusão de possíveis recomendações já avaliadas
//  Funciona como NOT EXISTS em SQL
// Grafo: os caminhos usuário -> negócio em comum -> outro usuário -> negócio recomendado, para as 3 melhores recomendações
// Se aparecer vazio, colocar outro âncora
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})-[r1:REVIEWED]->(:Business)<-[r2:REVIEWED]-(o:User)-[r3:REVIEWED]->(rec:Business)
WHERE o <> u
  AND r1.stars >= 4
  AND r2.stars >= 4
  AND r3.stars >= 4
  AND NOT (u)-[:REVIEWED]->(rec)
WITH u, rec,
     count(DISTINCT o)       AS indicacoes,
     round(avg(r3.stars), 2) AS nota_media
ORDER BY indicacoes DESC, nota_media DESC
LIMIT 3
MATCH p = (u)-[r1:REVIEWED]->(:Business)<-[r2:REVIEWED]-(o:User)-[r3:REVIEWED]->(rec)
WHERE o <> u
  AND r1.stars >= 4
  AND r2.stars >= 4
  AND r3.stars >= 4
RETURN p,
       rec.name AS recomendacao,
       rec.city AS cidade,
       indicacoes,
       nota_media
LIMIT 25;


// Qual a melhor ligação entre 2 usuários
// Usa 2 âncoras (2 IDs de usuários)
// Recomendado usar 2 IDs retirados do 2º bloco de consulta
// Pela modelação do grafo (2 nós e 1 relacionamento Avaliação)
//  O tamanho do grafo inclui os relacionamentos
MATCH (a:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'}), (b:User {id: 'bNJmIcxc_FRWxftI_vhpbg'})
MATCH p = shortestPath((a)-[:REVIEWED*..6]-(b))
RETURN p, length(p) AS relacionamentos_no_caminho;

// Mesma consulta com a sintaxe mais recente (Neo4j 5.21+ / Cypher 25):
MATCH p = SHORTEST 1 (a:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})-[:REVIEWED]-+(b:User {id: 'bNJmIcxc_FRWxftI_vhpbg'})
RETURN p, length(p) AS relacionamentos_no_caminho;
