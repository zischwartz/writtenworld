


 function Trie(vertex) {
  this.root = vertex;
  this.addWord = function(vertex, word) {
    if(!word.length) {
        return;
    } else {
      vertex.words.push(word);
      if(!(word[0] in vertex.children)) {
        vertex.children[word[0]] = new Vertex(word[0]);
      }
      this.addWord(vertex.children[word[0]], word.substring(1));
      return;
    }
  }

  this.retrieve = function(prefix) {
    var vertex = this.root;
    while(prefix.length) {
      vertex = vertex.children[prefix[0]];
      prefix = prefix.substring(1);
      if(!vertex) {
        return ''; 
      }   
    }   
    return vertex.words;
  }
}

function Vertex(val) {
  this.children = {};
  this.words = [];
  this.val = val;
} 

exports.Vertex= Vertex;
exports.Trie = Trie;

