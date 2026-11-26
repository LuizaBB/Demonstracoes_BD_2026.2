// PREPARAÇÃO DO AMBIENTE OPCIONAL (executar uma vez, antes de qualquer demonstração ou uso)
// Execute um comando por vez (selecione o bloco e rode).
// Modelo de grafo (importação manual):  (:User)-[:REVIEWED]->(:Business)
// Restrições criadas durante importação: 
//      id_User_key      NODE_KEY          User.id
//      id_Business_key  NODE_KEY          Business.id
//      id_REVIEWED_key  RELATIONSHIP_KEY  REVIEWED.id

// COnferir se as restrições aparecem como:
//      id_User_key      NODE_KEY          User.id
//      id_Business_key  NODE_KEY          Business.id
//      id_REVIEWED_key  RELATIONSHIP_KEY  REVIEWED.id
SHOW CONSTRAINTS;

// Caso não haja restrições pré-definidas, rodar trecho a seguir:
CREATE CONSTRAINT user_id_unico IF NOT EXISTS
FOR (u:User) REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT business_id_unico IF NOT EXISTS
FOR (b:Business) REQUIRE b.id IS UNIQUE;

// Conferir qual modelo de grafo foi carregado (comparar com o modelo descrito no início)
CALL db.schema.visualization();

// Conferir quantos nós de cada rótulo foram carregados
MATCH (n)
RETURN labels(n)[0] AS rotulo, count(*) AS total
ORDER BY total DESC;

// Conferir quantas avaliações foram carregadas
MATCH ()-[r:REVIEWED]->()
RETURN count(r) AS total_avaliacoes;

// Conferir o tipo de dado da avaliação (float ou inteiro)
MATCH ()-[r:REVIEWED]->()
RETURN r.stars AS valor, valueType(r.stars) AS tipo
LIMIT 3;

// Escolher as âncoras de demonstração (5 usuários com mais avaliações)
MATCH (u:User)-[r:REVIEWED]->()
RETURN u.id AS id, u.name AS nome, count(r) AS avaliacoes
ORDER BY avaliacoes DESC
LIMIT 5;

// OPCIONAL: Verificar índice único de cada usuário retornado no comando anterior
PROFILE
MATCH (u:User {id: 'COLE_AQUI_O_ID_DO_USUARIO'})
RETURN u.name AS usuario;

