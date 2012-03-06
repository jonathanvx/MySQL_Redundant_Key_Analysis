#!/bin/bash

### Config ###
SERVER=127.0.0.1
### End of Config ###

function dupkey {
pt-duplicate-key-checker --host=$SERVER --engines=innodb > dupkey.txt
pt-duplicate-key-checker --host=$SERVER --engines=myisam --no-clustered >> dupkey.txt
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
	mysql -h $SERVER -N -B -e"select concat(a.table_schema,'.',a.table_name) from (select table_schema,table_name,constraint_name,max(ordinal_position) as key_count from information_schema.key_column_usage group by table_schema,table_name,constraint_name having (constraint_name='PRIMARY' and key_count >1) or (constraint_name !='PRIMARY' and key_count=1)) as a group by a.table_schema,a.table_name having min(a.key_count) > 1;" > nonunique.txt
	echo -e "\nGenerated \033[38;5;148mnonunique.txt\033[39m in your current directory. This lists all the tables that do not have a unique or primary key that refers to \033[38;5;148mone\033[39m column (currently a limitation for pt-online-schema-change)."
}

function unused {
	mysql -N -B -e"select concat('alter table ',d.table_schema,'.',d.table_name,' drop index ',group_concat(index_name separator ',drop index '),';') stmt from (SELECT DISTINCT s.TABLE_SCHEMA, s.TABLE_NAME, s.INDEX_NAME FROM information_schema.statistics s LEFT JOIN information_schema.index_statistics iz ON (s.TABLE_SCHEMA = iz.TABLE_SCHEMA AND s.TABLE_NAME=iz.TABLE_NAME AND s.INDEX_NAME=iz.INDEX_NAME) WHERE iz.TABLE_SCHEMA IS NULL  AND s.NON_UNIQUE=1 AND s.INDEX_NAME!='PRIMARY' and (select rows_read+rows_changed from information_schema.table_statistics ts where ts.table_schema=s.table_schema and ts.table_name=s.table_name)>0) d group by table_schema,table_name;" > unused.txt
	echo -e "\ncreated file \033[38;5;148munused.txt\033[39m in your current directory. This is the \033[38;5;148mlist of indexes\033[39m that have not been used during the time you have run user_statistics on your MySQL server. \nThis list excludes UNIQUE and PRIMARY KEYs as well as indexes from tables that have not been used."
}

function unusedcheck {
if [ -f unused.txt ];
then
    echo -e "\nOutput of \033[38;5;148munused indexes list\033[39m already exist."
        read -p "Do you wish to remove the list and rerun the tool? [N/y] " yn
        case $yn in
          [Yy]* ) unused;;
        esac
else
        unused;
fi
}

function big25 {
	mysql -h $SERVER -N -B -e"SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME) FROM INFORMATION_SCHEMA.TABLES ORDER BY DATA_LENGTH + INDEX_LENGTH DESC LIMIT  25;" > big25.txt
	echo -e "\ncreated file \033[38;5;148mbig25.txt\033[39m in your current directory. This is the list of your \033[38;5;148mtop 25 largest tables\033[39m by the total of data and index size."
}


function big25check {
if [ -f big25.txt ];
then
    echo -e "\nOutput of \033[38;5;148mtop 25 largest tables list\033[39m already exist."
        read -p "Do you wish to remove the output and rerun the sql statement? [N/y] " yn
        case $yn in
          [Yy]* ) big25;;
        esac
else
        big25;
fi
}

function top25 {
mysql --host $SERVER -N -B -e"select concat(f.table_schema,'.',f.table_name) from ((select table_schema, table_name, rows_changed_x_indexes as counter from information_schema.TABLE_STATISTICS order by rows_changed_x_indexes desc limit 25) union (select table_schema,table_name, rows_read as counter from information_schema.TABLE_STATISTICS order by rows_read desc limit 25)) f straight_join information_schema.TABLES t on f.table_name = t.table_name and t.table_schema = f.table_schema order by f.counter desc limit 25;" > top25.txt
echo -e "\ncreated file \033[38;5;148mtop25.txt\033[39m in your current directory. This is the list of your \033[38;5;148mtop 25 most used tables\033[39m by the total of data and index size."
}

function top25check {
if [ -f top25.txt ];
then
    echo -e "\nOutput of \033[38;5;148mtop 25 most used tables list\033[39m already exist."
        read -p "Do you wish to remove the output and rerun the sql statement? [N/y] " yn
        case $yn in
          [Yy]* ) top25;;
        esac
else
        top25;
fi
}

function fill_list() {
	case $1 in
	[d]* ) cat dupkey.txt | grep -i 'ALTER TABLE' | sed 's/, ADD INDEX/;\n/gI' | grep -i 'ALTER TABLE' | tr -d "\`" > tmpdup1;;
	[u]* ) cat unused.txt | grep -i 'ALTER TABLE' > tmpdup1;;
	[l]* ) cat list.txt | grep -i 'ALTER TABLE' | tr -d "\`" > tmpdup1;;
	[a]* ) cat dupkey.txt unused.txt | grep -i 'ALTER TABLE' | sed 's/, ADD INDEX/;\n/gI' | grep -i 'ALTER TABLE' | tr -d "\`" | sort | uniq > tmpdup1;;
	* ) echo "Error! no file found"; exit;;
	esac
}

function dropkey() {
	if [ ! -f tmpdup1 ];
	then
		echo "Error! no tmpdup1 file found";
		exit;
	fi
	
	case $option in
               [big]* ) cat tmpdup1 | grep -f big25.txt > tmpdup2;
			ADDITION="the \033[38;5;148m25 largest\033[39m ";;
               [top]* ) cat tmpdup1 | grep -f top25.txt > tmpdup2;
			ADDITION="the \033[38;5;148m25 most used\033[39m ";;
               [all]* ) cat big25.txt top25.txt | sort | uniq > tmpdup3;
			cat tmpdup1 | grep -f tmpdup3 > tmpdup2;
			rm -f tmpdup3;
			ADDITION="the \033[38;5;148m25 largest and most used\033[39m ";;
                * ) cat tmpdup1 > tmpdup2; ADDITION="";;
        esac

	echo '#!/bin/bash' > dupkey.sh
        cat tmpdup2 | grep -v -f nonunique.txt | sed 's/\./ /g' | sed 's/ALTER TABLE //gI' | awk '{ print "pt-online-schema-change h=$SERVER,D="$1",t="$2,"--alter \"" substr($0, index($0,$3)) "\" ", "--drop-old-table"}' | sort -r | uniq |sort| uniq |  sed 's/$SERVER/'$SERVER'/g' >> dupkey.sh
	chmod a+x dupkey.sh
        cat tmpdup2 | grep -f nonunique.txt | sort | uniq > dupkey.sql
        
        rm -f tmpdup1
        rm -f tmpdup2

        echo -e "\nCreated bash script \033[38;5;148mdupkey.sh\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for "$ADDITION"tables that have a \033[38;5;148msingle-column unique key\033[39m and converted to \033[38;5;148mpt-online-schema-change\033[39m statements to run safely on your server."
        echo -e "\nCreated SQL script \033[38;5;148mdupkey.sql\033[39m.\nThis contains the suggested indexes to drop from \033[38;5;148mpt-duplicate-key-checker\033[39m, for "$ADDITION"tables that \033[38;5;148mdo not\033[39m have a \033[38;5;148msingle-column unique key\033[39m. You may need to perform a \033[38;5;148mRolling-Server Change\033[39m to implement these."
        
}


echo "This program will use tools to analyse your redundant indexes on your local MySQL database server and output actionable commands to implement their removal."
echo "Please note that it will only output text/sql/bash files. It will not run them. You will need to go over them and decide which commands you would like to run or not."
echo -e "\nThe tools you can run are:\n"
echo -e "[1] \033[38;5;148mDuplicate key checker\033[39m"
echo -e "[2] \033[38;5;148mDuplicate key checker\033[39m for the \033[38;5;148mtop 25 largest tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 largest tables can put your MySQL server under some temporary load)\n"
echo -e "[3] \033[38;5;148mDuplicate key checker\033[39m for the \033[38;5;148mtop 25 most used tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 most used tables can put your MySQL server under some temporary load)\n"
echo -e "[4] \033[38;5;148mDuplicate key checker\033[39m for the \033[38;5;148mtop 25 most used and largest tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 most used and largest tables can put your MySQL server under some temporary load)\n"
echo -e "[5] \033[38;5;148mUnused Indexes\033[39m (Requires USER_STATISTICS PATCH and for it to run a decent amount of time)"
echo -e "[6] \033[38;5;148mUnused Indexes\033[39m for the \033[38;5;148mtop 25 largest tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 largest tables can put your MySQL server under some temporary load)\n"
echo -e "[7] \033[38;5;148mUnused Indexes\033[39m for the \033[38;5;148mtop 25 most used tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 most used tables can put your MySQL server under some temporary load)\n"
echo -e "[8] \033[38;5;148mDuplicate key checker\033[39m for the \033[38;5;148mtop 25 most used and largest tablest\033[39m on your MySQL server. \n(Caution, finding the top 25 most used and largest tables can put your MySQL server under some temporary load)\n"
echo -e "[9] \033[38;5;148mEverything togther\033[39m. Both pt-duplicate-key-checker and unused indexes fused together. (May result in two 'alter table's for same table)"

while true; do
    read -p "Which of the following tools do you wish to run?[1-9 or (Q)uit] " opt
    case $opt in
        [1]* ) dupkeycheck; 
		nonuniquecheck; 
		fill_list "d";
		dropkey; 
		exit;;
        [2]* )  dupkeycheck; 
		nonuniquecheck; 
		option="big"; 
		big25check;
		fill_list "d"; 
		dropkey; 
		exit;;
        [3]* )  dupkeycheck;
                nonuniquecheck;
                option="top";
                top25check;
                fill_list "d";
		dropkey;
                exit;;
        [4]* )  dupkeycheck;
                nonuniquecheck;
                option="all";
                top25check;
		big25check;
		fill_list "d";
                dropkey;
                exit;;
        [5]* )  unusedcheck;
                nonuniquecheck;
                fill_list "u";
                dropkey;
                exit;;
        [6]* )  unusedcheck;
                nonuniquecheck;
                big25check;
		option="big";
		fill_list "u";
                dropkey;
                exit;;
        [7]* )  unusedcheck;
                nonuniquecheck;
                big25check;
                option="top";
                fill_list "u";
                dropkey;
                exit;;
        [8]* )  unusedcheck;
                nonuniquecheck;
                big25check;
                option="all";
                fill_list "u";
                dropkey;
                exit;;
        [9]* )  nonuniquecheck;
		unusedcheck;
		dupkeycheck;
                fill_list "a";
                dropkey;
                exit;;
	[qQ]* ) exit;;
        * ) echo "Please type 1, 2, 3, 4 or Q.";;
    esac
done
