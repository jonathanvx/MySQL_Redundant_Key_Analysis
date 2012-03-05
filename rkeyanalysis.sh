#!/bin/bash

### Config ###
SERVER=127.0.0.1
### End of Config ###

function dupkey {
#pt-duplicate-key-checker | grep 'ALTER TABLE' | tr -d "\`"  > dupkey.txt
pt-duplicate-key-checker --engines=innodb > dupkey.txt
pt-duplicate-key-checker --engines=myisam --no-clustered >> dupkey.txt
echo -e "\ncreated file \033[38;5;148mdupkey.txt\033[39m in your current directory. This is the output from \033[38;5;148mpt-duplicate-key-checker\033[39m."
}


function dupkeycheck {
if [ -f dupkey.txt ];
then
    echo -e "\nOutput of \033[38;5;148mduplicate key checker\033[39m already exist."
   	 read -p "Do you wish to remove the output and rerun the tool? [N/y] " yn
    	case $yn in
     	  [Yy]* ) dupkey;;
    	esac
else 
	dupkey;
fi
}

function nonuniquecheck {
if [ -f nonunique.txt ];
then
    echo -e "\nOutput of \033[38;5;148mnon-unique table list\033[39m already exist."
	read -p "Do you wish to remove the output and rerun the tool? [N/y] " yn
        case $yn in
          [Yy]* ) nonunique;;
	esac
else 
	nonunique;
fi
}


function nonunique {
mysql -N -B -e"select concat(a.table_schema,'.',a.table_name) from
(select table_schema,table_name,constraint_name,max(ordinal_position) as key_count from information_schema.key_column_usage group by table_schema,table_name,constraint_name having (constraint_name='PRIMARY' and key_count >1) or (constraint_name !='PRIMARY' and key_count=1)) as a group by a.table_schema,a.table_name having min(a.key_count) > 1;" > nonunique.txt
echo -e "\nGenerated \033[38;5;148mnonunique.txt\033[39m in your current directory. This lists all the tables that do not have a unique or primary key that refers to \033[38;5;148mone\033[39m column (currently a limitation for pt-online-schema-change)."
}

function dupkey_osc {
echo '#!/bin/bash' > dupkey.sh
cat dupkey.txt | grep 'ALTER TABLE' | sed 's/, ADD INDEX/;\n/g' | grep 'ALTER TABLE' | tr -d "\`" | grep -v -f nonunique.txt | sed 's/\./ /g' | sed 's/ALTER TABLE //g' | awk '{ print "pt-online-schema-change h=$SERVER,D="$1",t="$2,"--alter \"" substr($0, index($0,$3)) "\" ", "--drop-old-table"}' | sort | uniq |  sed 's/$SERVER/'$SERVER'/g' >> dupkey.sh
chmod a+x dupkey.sh
echo -e "\nCreated bash script \033[38;5;148mdupkey.sh\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for tables that have a \033[38;5;148msingle-column unique key\033[39m and converted to \033[38;5;148mpt-online-schema-change\033[39m statements to run safely on your server."
}

function dupkey_sql {
cat dupkey.txt  | grep 'ALTER TABLE' | tr -d "\`" | grep -f nonunique.txt |  sed 's/, ADD INDEX/;\n/g' | grep 'ALTER TABLE'  > dupkey.sql
echo -e "\nCreated SQL script \033[38;5;148mdupkey.sql\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for tables that \033[38;5;148mdo not\033[39m have a \033[38;5;148msingle-column unique key\033[39m. You may need to perform a \033[38;5;148mRolling-Server Change\033[39m to implement these."
}

function top25 {
mysql -N -B -e"SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME) FROM INFORMATION_SCHEMA.TABLES ORDER BY DATA_LENGTH + INDEX_LENGTH DESC LIMIT  25;" > top25.txt
echo -e "\ncreated file \033[38;5;148mtop25.txt\033[39m in your current directory. This is the list of your \033[38;5;148mtop 25 largest tables\033[39m by the total of data and index size."
}

function top25check {
if [ -f top25.txt ];
then
    echo -e "\nOutput of \033[38;5;148mtop 25 largest tables list\033[39m already exist."
        read -p "Do you wish to remove the output and rerun the sql statement? [N/y] " yn
        case $yn in
          [Yy]* ) top25;;
        esac
else
        top25;
fi
}

function dupkey25_osc {
if [ -f top25.txt ];
then
	echo '#!/bin/bash' > dupkey.sh
	cat dupkey.txt | grep 'ALTER TABLE' | sed 's/, ADD INDEX/;\n/g' | grep 'ALTER TABLE' | tr -d "\`" | grep -v -f nonunique.txt | grep -f top25.txt | sed 's/\./ /g' | sed 's/ALTER TABLE //g' | awk '{ print "pt-online-schema-change h=$SERVER,D="$1",t="$2,"--alter \"" substr($0, index($0,$3)) "\" ", "--drop-old-table"}' | sort | uniq |  sed 's/$SERVER/'$SERVER'/g' >> dupkey25.sh
chmod a+x dupkey.sh
	echo -e "\nCreated bash script \033[38;5;148mdupkey25.sh\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for tables that have a \033[38;5;148msingle-column unique key\033[39m, from the \033[38;5;148mtop 25 largest tables\033[39m and converted to \033[38;5;148mpt-online-schema-change\033[39m statements to run safely on your server."
else
	echo -e "\nSome error has occured. Could not find top25.txt"
fi
}

function dupkey25_sql {
if [ -f top25.txt ];
then
	cat dupkey.txt  | grep 'ALTER TABLE' | tr -d "\`" | grep -f nonunique.txt | grep -f top25.txt | sed 's/, ADD INDEX/;\n/g' | grep 'ALTER TABLE'  > dupkey25.sql
	echo -e "\nCreated SQL script \033[38;5;148mdupkey25.sql\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for tables that \033[38;5;148mdo not\033[39m have a \033[38;5;148msingle-column unique key\033[39m and are in the \033[38;5;148mtop 25 largest tables\033[39m in your MySQL server. You may need to perform a \033[38;5;148mRolling-Server Change\033[39m to implement these."
else
        echo -e "\nSome error has occured. Could not find top25.txt"
fi
}


echo "This program will use tools to analyse your redundant indexes on your local MySQL database server and output actionable commands to implement their removal."
echo "Please note that it will only output text/sql/bash files. It will not run them. You will need to go over them and decide which commands you would like to run or not."
echo -e "\nThe tools you can run are:\n"
echo -e "[1] \033[38;5;148mDuplicate key checker\033[39m"
echo -e "[2] \033[38;5;148mDuplicate key checker\033[39m for the \033[38;5;148mtop 25 largest tablesr\033[39m on your MySQL server. \n(Caution, finding the top 25 largest tables can put your MySQL server under some temporary load)\n"
while true; do
    read -p "Which of the following tools do you wish to run?[1,2 or (Q)uit] " opt
    case $opt in
        [1]* ) dupkeycheck; nonuniquecheck; dupkey_osc; dupkey_sql; exit;;
        [2]* ) dupkeycheck; nonuniquecheck; top25check; dupkey25_osc; dupkey25_sql; exit;;
	[qQ3]* ) exit;;
        * ) echo "Please type 1, 2 or Q.";;
    esac
done
