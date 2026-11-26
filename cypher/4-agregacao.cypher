// 04 - AGREGAÇÃO com Yelp Open Dataset
// Como SGBD não relacional, o Neo4j apresenta agregação como alternativa ao JOIN
// RETURN e WITH, quando não são funções de agregação (padrão) funcionam como chaves de agrupamento
// Executar um bloco por vez

// Conferir avaliações e notas médias por cidade
// MWITH calcula avaliações, ORDER usa resultado de avaliações depois de realizado
//  Busca encadeada
// Grafo resultante: Estabelimentos da cidade com mais avaliações acompanhado de quem avaliou
MATCH (b:Business)<-[r:REVIEWED]-(:User)
WITH b.city                 AS cidade,
     count(r)               AS avaliacoes,
     count(DISTINCT b)      AS negocios,
     round(avg(r.stars), 2) AS nota_media
ORDER BY avaliacoes DESC
LIMIT 1
MATCH (neg:Business {city: cidade})<-[rel:REVIEWED]-(usr:User)
RETURN neg, rel, usr, cidade, avaliacoes, negocios, nota_media
LIMIT 25;


// COnsultar os melhores estabelecimentos com um número mínimo x de avaliações
// WITH faz o cálculo da avaliação, WHERE usa resultado de avaliação
//  Busca encadeada simples
//  Conjunto WITH e WHERE equivalente a HAVING em SQL
// Grafo resultante: os 5 melhores negócios e os usuários que os avaliaram.
// Ajustar o inteiro de LIMIT para obter mais ou menos estabelecimentos
MATCH (b:Business)<-[r:REVIEWED]-(:User)
WITH b, count(r) AS avaliacoes, avg(r.stars) AS media
WHERE avaliacoes >= 5
ORDER BY media DESC, avaliacoes DESC
LIMIT 5
MATCH (b)<-[rel:REVIEWED]-(usr:User)
RETURN b, rel, usr,
       b.name AS negocio,
       avaliacoes,
       round(media, 2) AS nota_media
LIMIT 40;

