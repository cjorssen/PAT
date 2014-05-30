trouminimal = "2em"

-- On crée deux noeuds: Une glue (id 10) de type \xleaders (les leaders
-- sont des glues), et un noeud spec (id 47). Ce dernier n'est que la
-- spécification d'une glue (largeur, stretch, etc.).  Ici c'est
-- l'équivalent de "0pt plus 1fil" (si je me souviens bien); on assigne
-- ensuite cette spécification à la glue, que pour des raisons techniques
-- que j'ai oubliées on ne peut pas régler directement.  Enfin on assigne
-- à la glue, qui est un leader, l'élément répété (ici la boîte
-- préalablement créée).

local HLIST, VLIST, GLUE, SPEC = node.id('hlist'), node.id('vlist'), node.id('glue'), node.id('glue_spec')
--local XLEADERS = node.subtype('xleaders')
local points, points_spec = node.new(GLUE, 102), node.new(SPEC)
--local points, points_spec = node.new(10, 102), node.new(47)
points_spec.stretch, points_spec.stretch_order = 1, 2
points.spec = points_spec
points.leader = node.copy(tex.box['point'])

local function bon_noeud (item)
  return node.has_attribute(item, luatexbase.attributes['gapattribute'])
       and not (item.id == HLIST and item.subtype == 3) -- Boîte d'indentation.
       and not (item.id == GLUE and item.subtype == 15) -- \parfillskip
end

local trouloop

-- Voilà la fonction qui va passer en revue tous les noeuds d'une
-- ligne. Le premier argument est la tête de la ligne, c'est-à-dire son
-- premier noeud. Le second (set) est la quantité de stretch/shrink
-- utilisé pour justifier la ligne par rapport à la quantité disponible,
-- le troisième (sign) est un nombre représentant si la justification a
-- été faite par stretch ou shrink, enfin le quatrième (order) indique
-- l'ordre du stretch/shrink (fini, genre 5pt, ou infini, comme 1fil ou
-- 1fill, le second étant un inifini d'ordre supérieur).

local function trouer (head, set, sign, order, linetype)
   local item, first, done = head, true
   -- On fait une boucle sur tous les noeuds de la ligne (glyphes et
   -- espaces essentiellement). Les seuls qui nous intéressent sont ceux
   -- qui ont l'attribut \gapattribute.
   while item do
     if bon_noeud (item) then
       done = true
  	 local end_node = item
	   -- Quand on en a trouvé un, on récupère tous ceux 
	   -- qui suivent ayant aussi l'attribut.
         while end_node.next and bon_noeud(end_node.next) do
            end_node = end_node.next
         end

       -- On calcule la largeur que cette séquence de noeuds (des glyphes
       -- et des espaces) a avec les glues spécifiées comme la ligne
       -- (c'est-à-dire qu'on mesure la largeur de cette séquence dans la
       -- ligne en question).  (Remarque qu'on mesure jusqu'à
       -- "end_node.next", c'est-à-dire le noeud qui suit end_node --
       -- dernier noeud avec l'attribut -- parce que "node.dimensions"
       -- mesure en fait jusqu'au noeud précédent sont dernier
       -- argument. Pas très clair, mais c'est comme ça.)
         local width = node.dimensions(set, sign, order, item, end_node.next)


       -- On crée une boîte horizontale de même dimension remplie avec une
       -- copie de notre glue-leader, donc une boîte avec des points. Il
       -- faut aussi régler la largeur de la boîte, car "width" dans
       -- "node.hpack" ne fait que spécifier la largeur que doit couvrir
       -- le matériau dans la boîte, pas la largeur de la boîte elle-même
       -- (ce sont deux choses indépendantes). "TLT" indique la direction
       -- de l'écriture, obligatoire sinon LuaTeX plante.

       local point_box = node.new(0, 0)
       point_box.list = node.hpack(node.copy(points), width, "exactly")
       point_box.dir, point_box.width = "TLT", width
       texio.write_nl(point_box.width)

       -- Maintenant on retire tous les noeuds qu'on a trouvés. C'est le texte
       -- qu'on efface. Note qu'au sortir de la boucle, "item" est soit un noeud
       -- soit rien du tout (parce que le dernier noeud de la liste avait l'attribut).
       while item and not (item == end_node.next) do
          local p = item
          item = item.next
          head = node.remove(head, p)
       end

       -- On n'a plus qu'à insérer notre boîte de points. Si le noeud qu'on a
       -- attrapé au départ n'est pas le premier de la liste, ou si de toute
       -- façon la largeur de notre boîte dépasse "trouminimal", on n'insère tel quel.
       if not first or width > tex.sp(trouminimal) or linetype ~= 1 then
          -- Si item est un noeud (voir boucle précédente), il faut insérer la
          -- boîte avant, s'il est "nil", c'est qu'on est à la fin de la liste
          -- et il faut insérer après. Dans les deux cas on réajuste head à ce
          -- retourne node.insert_before/after, parce que la liste ainsi modifiée
          -- (représentée par sa tête head) peut avoir "changé de tête" (si le noeud
          -- inséré l'a été en première position. On réajute aussi item pour la suite
          -- de notre boucle.
          local insert = item and node.insert_before or node.insert_after
          head = insert(head, item, node.copy(point_box))
          item = end_node.next
       else
          -- Si on est avec le premier noeud, et que la boîte est inférieure à
          -- "trouminimal", on insère rien du tout. Au contraire, si le noeud qui
          -- suit est un glue (un espace), on le supprime, sinon la ligne commencerait
          -- avec un léger blanc.
          if end_node.next and end_node.next.id == 10 then
             item = end_node.next.next
             head = node.remove(head, end_node.next)
          end
       end
    else -- Ce bout, c'est juste qu'on passe un noeud sans l'attribut.
      if item.id == HLIST and item.list then
        local newhead, change = trouer(item.list, item.glue_set, item.glue_sign, item.glue_order, item.subtype)
        if newhead and change then
          local hbadness = tex.hbadness
          tex.hbadness = 10000
    		  item.list = node.hpack(newhead, item.width, "exactly")
          tex.hbadness = hbadness
        end
      elseif item.id == VLIST then
        item.list = trouloop(item.list)
      end
	    item = item.next
    end
      -- Ce n'est important bien sûr qu'après le premier noeud.
      first = false
   end
   return head, done
end

function trouloop (head)
  for item in node.traverse(head) do
    if item.id == HLIST then
      local newhead, change = trouer(item.list, item.glue_set, item.glue_sign, item.glue_order, item.subtype)
      if newhead and change then
        local hbadness = tex.hbadness
        tex.hbadness = 10000
        item.list = node.hpack(newhead, item.width, "exactly")
        tex.hbadness = hbadness
      end
    elseif item.id == VLIST then
      trouloop(item.list)
    end
  end
	return head
end

local function mtrouloop (head, display, penalties)
  head = node.mlist_to_hlist(head, display, penalties)
  trouloop(head)
  return head
end

luatexbase.add_to_callback("post_linebreak_filter",trouloop,"trouer",1)
luatexbase.add_to_callback("mlist_to_hlist",mtrouloop,"trouer",1)


-- Local Variables:
-- coding: utf-8-unix
-- End:
