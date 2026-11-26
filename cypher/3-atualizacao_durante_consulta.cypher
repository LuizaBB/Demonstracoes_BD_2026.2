// 03 - ATUALIZAÇÃO DURANTE CONSULTAS
// Cypher permite ler, calcular, gravar e retornar valores já atualizados
//  dentro de uma instrução
// Execute um bloco por vez. Use o mesmo id de usuário do arquivo 01.

// Bloco 1: Ler, agregar e gravar

// Verificação: encontrar o usuário para ler (confirmar se ainda está no grafo)
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})
RETURN u;

// Execução: conta as avaliações, calcula a média e grava no nó,
// devolvendo o nó já atualizado na mesma instrução
// Localiza o usuário novamente, aplica novos atributos para o nó (com cáclulo de média por função nativa) e retorna o nó atualizado
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})-[r:REVIEWED]->(:Business)
WITH u, count(r) AS qtd, avg(r.stars) AS media
SET u.avaliacoes_carregadas = qtd,
    u.media_calculada       = round(media, 2)
RETURN u,
       u.name                  AS usuario,
       u.review_count          AS total_segundo_yelp,
       u.avaliacoes_carregadas AS total_no_grafo,
       u.media_calculada       AS media_no_grafo;

// OPCIONAL: Confirmar as novas informações, com o mesmo comando do início
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})
RETURN u;


// Bloco 2: Criar e atualizar
// ON CREATE: cria o nó (se não existir)
MATCH (b:Business)
WITH b.city AS cidade, count(*) AS negocios
ORDER BY negocios DESC
LIMIT 1
MERGE (c:Cidade {nome: cidade})
  ON CREATE SET c.criada_em = datetime(), c.consultas = 1
  ON MATCH  SET c.ultima_consulta = datetime(), c.consultas = c.consultas + 1
RETURN c,
       c.nome AS cidade,
       c.consultas AS consultas,
       c.criada_em AS criada_em,
       c.ultima_consulta AS ultima_consulta;


// OPCIONAL: Limpeza para retirar demonstração
MATCH (u:User {id: 'RgDVC3ZUBqpEe6Y1kPhIpw'})
REMOVE u.avaliacoes_carregadas, u.media_calculada;

MATCH (c:Cidade)
DETACH DELETE c;

