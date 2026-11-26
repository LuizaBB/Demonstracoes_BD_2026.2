"""
Importa subconjunto do Yelp Open Dataset (JSON) para o Neo4j em CSV (facilitar importação), com modelo:
  (:User {id,name,review_count,average_stars})
  (:Business {id,name,address,city,state,stars,review_count})
  (:User)-[:REVIEWED {id,stars,text,date}]->(:Business)
"""
import argparse
import csv
import json
import os
import sys
from collections import Counter
from neo4j import GraphDatabase

ARQ_NEGOCIO = "yelp_academic_dataset_business.json"
ARQ_AVALIACAO = "yelp_academic_dataset_review.json"
ARQ_USUARIO = "yelp_academic_dataset_user.json"


def linhas_json(caminho): #dicionario temporario por linha de arquivo (padrao CSV)
    with open(caminho, "r", encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if not linha:
                continue
            try:
                yield json.loads(linha)
            except json.JSONDecodeError:
                continue


def em_lotes(itens, tamanho):
    lote = []
    for item in itens:
        lote.append(item)
        if len(lote) >= tamanho:
            yield lote
            lote = []
    if lote:
        yield lote


def listar_cidades(pasta):
    cont = Counter()
    for n in linhas_json(os.path.join(pasta, ARQ_NEGOCIO)):
        cont[(n.get("city") or "", n.get("state") or "")] += 1
    print("Cidades com mais negócios:")
    for (cidade, estado), qtd in cont.most_common(15):
        print(f"  {cidade} ({estado}): {qtd}")


def selecionar(pasta, cidade, max_negocios, max_avaliacoes, max_texto): #subconjunto do dataset
    
    negocios = {} #estabelecimentos (business)
    for n in linhas_json(os.path.join(pasta, ARQ_NEGOCIO)):
        if cidade and (n.get("city") or "").lower() != cidade.lower():
            continue
        negocios[n["business_id"]] = {
            "id": n["business_id"],
            "name": n.get("name"),
            "address": n.get("address"),
            "city": n.get("city"),
            "state": n.get("state"),
            "stars": float(n["stars"]) if n.get("stars") is not None else None,
            "review_count": n.get("review_count"),
        }
        if len(negocios) >= max_negocios:
            break

    avaliacoes = [] #avaliações (reviews)
    ids_usuarios = set()
    for r in linhas_json(os.path.join(pasta, ARQ_AVALIACAO)):
        if r.get("business_id") not in negocios:
            continue
        texto = (r.get("text") or "")[:max_texto]
        avaliacoes.append({
            "id": r["review_id"],
            "user_id": r["user_id"],
            "business_id": r["business_id"],
            "stars": int(round(float(r["stars"]))),
            "text": texto,
            "date": (r.get("date") or "")[:10],
        })
        ids_usuarios.add(r["user_id"])
        if len(avaliacoes) >= max_avaliacoes:
            break

    usuarios = {} #usuários (users)
    faltam = set(ids_usuarios)
    for u in linhas_json(os.path.join(pasta, ARQ_USUARIO)):
        uid = u.get("user_id")
        if uid in faltam:
            usuarios[uid] = {
                "id": uid,
                "name": u.get("name"),
                "review_count": u.get("review_count"),
                "average_stars": u.get("average_stars"),
            }
            faltam.discard(uid)
            if not faltam:
                break

    avaliacoes = [a for a in avaliacoes if a["user_id"] in usuarios] #mantém avaliações que usuário foi encontrado
    return negocios, usuarios, avaliacoes


def limpar(valor): #aplica padrão CSV trocando linha por espaço
    if isinstance(valor, str):
        return " ".join(valor.split())
    return valor


def exportar_csv(negocios, usuarios, avaliacoes, destino): #gera CSV final
    os.makedirs(destino, exist_ok=True)
    conjuntos = [
        ("negocios.csv", ["id", "name", "address", "city", "state", "stars", "review_count"],
         negocios.values()),
        ("usuarios.csv", ["id", "name", "review_count", "average_stars"], usuarios.values()),
        ("avaliacoes.csv", ["id", "user_id", "business_id", "stars", "text", "date"], avaliacoes),
    ]
    for nome, colunas, linhas in conjuntos:
        with open(os.path.join(destino, nome), "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(colunas)
            for l in linhas:
                w.writerow([limpar(l.get(c)) for c in colunas])
    print(f"CSVs gerados em: {destino}")


def gravar(negocios, usuarios, avaliacoes, uri, usuario, senha, tamanho_lote):

    driver = GraphDatabase.driver(uri, auth=(usuario, senha))
    with driver, driver.session() as s:
        for comando in (
            "CREATE CONSTRAINT user_id_unico IF NOT EXISTS "
            "FOR (u:User) REQUIRE u.id IS UNIQUE",
            "CREATE CONSTRAINT business_id_unico IF NOT EXISTS "
            "FOR (b:Business) REQUIRE b.id IS UNIQUE",
        ):
            try:
                s.run(comando).consume()
            except Exception as erro:  # noqa: BLE001
                print(f"Aviso: restrição não criada ({erro}). Seguindo com a carga.")

        for lote in em_lotes(list(negocios.values()), tamanho_lote):
            s.run("UNWIND $linhas AS l MERGE (b:Business {id: l.id}) "
                  "SET b.name=l.name, b.address=l.address, b.city=l.city, "
                  "b.state=l.state, b.stars=l.stars, b.review_count=l.review_count",
                  linhas=lote).consume()

        for lote in em_lotes(list(usuarios.values()), tamanho_lote):
            s.run("UNWIND $linhas AS l MERGE (u:User {id: l.id}) "
                  "SET u.name=l.name, u.review_count=l.review_count, "
                  "u.average_stars=l.average_stars", linhas=lote).consume()

        for lote in em_lotes(avaliacoes, tamanho_lote):
            s.run("UNWIND $linhas AS l "
                  "MATCH (u:User {id: l.user_id}), (b:Business {id: l.business_id}) "
                  "MERGE (u)-[r:REVIEWED {id: l.id}]->(b) "
                  "SET r.stars=l.stars, r.text=l.text, r.date=l.date",
                  linhas=lote).consume()

def main():
    p = argparse.ArgumentParser(description="Importa um subconjunto do Yelp para o Neo4j")
    p.add_argument("--pasta", required=True, help="pasta com os arquivos .json do Yelp")
    p.add_argument("--cidade", help="importa só negócios desta cidade (ex.: Philadelphia)")
    p.add_argument("--max-negocios", type=int, default=2000)
    p.add_argument("--max-avaliacoes", type=int, default=50000)
    p.add_argument("--max-texto", type=int, default=300, help="caracteres guardados do texto")
    p.add_argument("--lote", type=int, default=1000)
    p.add_argument("--listar-cidades", action="store_true")
    p.add_argument("--exportar-csv", metavar="PASTA",
                   help="gera negocios.csv, usuarios.csv e avaliacoes.csv na pasta (para o Import do Aura)")
    p.add_argument("--dry-run", action="store_true", help="só conta, não grava no Neo4j")
    a = p.parse_args()

    for nome in (ARQ_NEGOCIO, ARQ_AVALIACAO, ARQ_USUARIO):
        if not os.path.isfile(os.path.join(a.pasta, nome)):
            sys.exit(f"Arquivo não encontrado: {os.path.join(a.pasta, nome)}")

    if a.listar_cidades:
        listar_cidades(a.pasta)
        return

    negocios, usuarios, avaliacoes = selecionar(
        a.pasta, a.cidade, a.max_negocios, a.max_avaliacoes, a.max_texto)
    print(f"Selecionados: {len(negocios)} negócios, {len(usuarios)} usuários, "
          f"{len(avaliacoes)} avaliações "
          f"(nós: {len(negocios) + len(usuarios)}, relacionamentos: {len(avaliacoes)})")

    if a.dry_run:
        print("Dry-run: nada foi gravado.")
        return

    if a.exportar_csv:
        exportar_csv(negocios, usuarios, avaliacoes, a.exportar_csv)
        return

    uri = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
    usuario = os.environ.get("NEO4J_USER", "neo4j")
    senha = os.environ.get("NEO4J_PASSWORD")
    if not senha:
        sys.exit("Defina a variável de ambiente NEO4J_PASSWORD.")
    gravar(negocios, usuarios, avaliacoes, uri, usuario, senha, a.lote)
    print("Importação concluída.")


if __name__ == "__main__":
    main()
