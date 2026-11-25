// =====================================================================
// 02 - CRUD SIMPLES, modificação de Yelp Open Dataset
// Usa IDS não relacionados ao Yelp user_lucas_01, business_tech_01, review_001
// Executar um bloco por vez, representando a ordem de CRUD
// Se rodar o CREATE duas vezes, a restrição de unicidade (arquivo 00)
// recusa o segundo: rode o bloco D2 para limpar e recomece.
// =====================================================================

// CREATE: cria usuário, negócio e a avaliação que liga os dois,
// Modelo do grafo: os dois nós novos, avaliação os ligando
// Executar este bloco de comando repetidas vezes não causa duplicidade, devido às restrições
CREATE (u:User {id: 'user_lucas_01', name: 'Lucas', review_count: 1, average_stars: 5.0})
CREATE (b:Business {id: 'business_tech_01', name: 'Tech Café Maceió',
                    address: 'Campus A. C. Simões', city: 'Maceió', stars: 5.0})
CREATE (u)-[r:REVIEWED {id: 'review_001', stars: 5,
                        text: 'Ótimo ambiente para estudar.', date: '2026-05-30'}]->(b)
RETURN u, r, b;

// READ: Leitura de entidades por correspodência de padrão
//Aplicável a qualquer ID
MATCH (u:User {id: 'user_lucas_01'})-[r:REVIEWED]->(b:Business)
RETURN u, r, b;


// UPDATE: Altera propriedades dos nós e relacionamentos
// Retorna mesmo grafo, porém com novas informações
MATCH (u:User {id: 'user_lucas_01'})-[r:REVIEWED]->(b:Business)
SET u.name  = 'Lucas Silva',
    r.stars = 4,
    r.text  = 'Bom ambiente, mas costuma ficar lotado.'
RETURN u, r, b;


// DELETE 1: apaga apenas a avaliação (relacionamento)
// usuário e negócio permanecem
MATCH (:User {id: 'user_lucas_01'})-[r:REVIEWED {id: 'review_001'}]->(:Business)
DELETE r;
// conferir se os nós continuam lá, mas sem conexão
MATCH (n)
WHERE n.id IN ['user_lucas_01', 'business_tech_01']
RETURN n;

// DELETE 2: apaga os nós junto com qualquer relacionamento que ainda estiver ligado a eles
// DELETE (simples) não funciona corretamente se ainda possuir relacionamentos
MATCH (n)
WHERE n.id IN ['user_lucas_01', 'business_tech_01']
DETACH DELETE n;
// Conferir se realmente foram deletados
//Não deve aparecer nenhum resultado
MATCH (n)
WHERE n.id IN ['user_lucas_01', 'business_tech_01']
RETURN n;
