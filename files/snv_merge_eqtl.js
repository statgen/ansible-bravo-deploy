/* Merging an indicator of which SNVs also appear in the eQTL collection. 
 *   Facilitates the display and highlighting of which snvs are also eqtls.
 *   BRAVO database needs to be specified at the command line.
 */


/***************
* Safety Check *
***************/
let eqtlName = "eqtl_susie"

if(!db.getCollectionNames().includes(eqtlName)){
  console.error(`In DB, ${db.getName()}, did NOT find collection ${eqtlName}.`)
  quit(1)
}

console.log(`In DB, ${db.getName()}, found collection ${eqtlName}.`)

/*****************************
* Index to facilitate lookup *
*****************************/
console.log("creating indexes")
db.snv.createIndex({variant_id: 1})
db.eqtl_susie.createIndex({variant_id: 1})

/*************************
* Define Update Pipeline *
*************************/
// limit amount of data from snv documents being handled
let pProjectInit = {$project: {variant_id: 1}}

// look up corresponding eqtl documents
let pLookup = {$lookup: {from: "eqtl_susie", localField: "variant_id", foreignField: "variant_id", as: "eqtls"}}

// match only snvs that have eqtls
let pMatch  = {$match: {"eqtls": {$ne: []}}}

// trim results to only fields required
let pProjectFinal = {$project: {is_eqtl: {$literal: true}}}

// merge stage to write data back to snv collection
let pMerge = {$merge: {into: "snv", on: "_id", whenMatched: "merge"}}

// Combine to form pipeline specification
let pipeline = [pProjectInit, pLookup, pMatch, pProjectFinal, pMerge]

/*************************
* Execute Update Pipeline *
*************************/
let result = db.snv.aggregate(pipeline)
