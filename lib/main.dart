// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:uuid/uuid.dart';

void main() async {
  await Hive.initFlutter();
  var box = await Hive.openBox('items');
  runApp(MyApp(db: box));
}

const List<String> list = ['L', 'mL', 'Kg', 'g'];

class MyApp extends StatelessWidget {
  final Box<dynamic> db;

  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Comparador de preço',
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: lightColorScheme,
        ),
        darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: darkColorScheme),
        home: MyHomePage(db: db),
      );
    });
  }
}

class MyHomePage extends StatefulWidget {
  final Box<dynamic> db;

  const MyHomePage({super.key, required this.db});

  @override
  // ignore: no_logic_in_create_state
  State<MyHomePage> createState() => MainPage(db: db);
}

class MainPage extends State<MyHomePage> with RouteAware {
  final Box<dynamic> db;
  double budget = 0;
  Color green = Colors.green;
  Color blue = Colors.blue;
  SliverList items = SliverList(
    delegate: SliverChildListDelegate([
      const SizedBox(height: 50),
      const Text(
        "Nenhum item cadastrado",
        style: TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      const Text(
        "Clique no botão + para adicionar um item",
        style: TextStyle(fontSize: 15),
        textAlign: TextAlign.center,
      ),
    ]),
  );

  MainPage({required this.db});

  SliverList renderItems(double budget, Color green, Color blue) {
    if (db.isEmpty)
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 50),
          const Text(
            "Nenhum item cadastrado",
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const Text(
            "Clique no botão + para adicionar um item",
            style: TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    List<Item> items =
        db.toMap().entries.map((e) => Item.fromString(e.value)).toList();
    double smallestPricePerUnit = items[0].pricePerUnit,
        bestComeOut = items[0].resultingMass(budget),
        smallestPrice = items[0].price;

    for (var item in items) {
      double pricePerUnit = item.pricePerUnit;
      double resultingMass = item.resultingMass(budget);
      if (pricePerUnit < smallestPricePerUnit)
        smallestPricePerUnit = pricePerUnit;
      if (resultingMass > bestComeOut) bestComeOut = resultingMass;
      if (item.price < smallestPrice) smallestPrice = item.price;
    }

    if (budget < smallestPrice) bestComeOut = -1;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext _, int index) {
          Item e = items[index];
          Color bgColor = e.pricePerUnit == smallestPricePerUnit
              ? green
              : e.resultingMass(budget) == bestComeOut
                  ? blue
                  : Theme.of(context).focusColor;

          Color textColor = Theme.of(context).colorScheme.onPrimaryContainer;
          return Container(
            margin: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              color: bgColor,
            ),
            child: OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditElement(
                      item: e,
                      db: db,
                    ),
                  ),
                );
                setState(() {
                  this.items = renderItems(this.budget, this.green, this.blue);
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(
                  color: Colors.transparent,
                ),
                padding: const EdgeInsets.all(15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Column(children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        fontSize: 20,
                        color: textColor,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    Text(
                      e.readableGeneralInfo,
                      style: TextStyle(color: textColor),
                      textAlign: TextAlign.left,
                    ),
                  ]),
                  Expanded(
                    flex: 2,
                    child: Column(children: [
                      Text(
                        e.readablePricePerUnit,
                        style: TextStyle(color: textColor),
                        textAlign: TextAlign.right,
                      ),
                      Text(
                        e.readableSummary(budget),
                        style: TextStyle(color: textColor),
                        textAlign: TextAlign.right,
                      ),
                    ]),
                  )
                ],
              ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    green = Colors.green.harmonizeWith(Theme.of(context).colorScheme.primary);
    blue =
        Colors.lightBlue.harmonizeWith(Theme.of(context).colorScheme.primary);
    items = renderItems(budget, green, blue);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Comparador de preços"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Orçamento',
                        prefix: Text('R\$ '),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[+-]?([0-9]+([.][0-9]*)?)')),
                      ],
                      onChanged: (value) {
                        double newValue = 0;
                        if (value != "") {
                          newValue = double.parse(value);
                        }
                        setState(() {
                          budget = newValue;
                          items = renderItems(budget, green, blue);
                        });
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Text("Menor preço por unidade")
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Text("Melhor encaixe com o orçamento")
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: CustomScrollView(
                slivers: [
                  items,
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddElement(db: db),
            ),
          );
          setState(() {
            items = renderItems(budget, green, blue);
          });
        },
        tooltip: 'Adicionar produto',
        shape: const StadiumBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddElement extends StatefulWidget {
  final Box<dynamic> db;
  const AddElement({super.key, required this.db});

  @override
  // ignore: no_logic_in_create_state
  State<AddElement> createState() => _AddElement(db: db);
}

class _AddElement extends State<AddElement> {
  final Box<dynamic> db;
  final name = TextEditingController();
  final price = TextEditingController();
  final mass = TextEditingController();
  final unit = TextEditingController();
  String? dropdownValue;
  final _formKey = GlobalKey<FormState>();

  _AddElement({required this.db});

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    mass.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Adicionar produto"),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: Text(
                    "Adicionar produto",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: name,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira um nome';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nome',
                        ),
                        keyboardType: TextInputType.text,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.singleLineFormatter,
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: price,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Insira o preço';
                          if (double.tryParse(value) == null)
                            return "Preço inválido";
                          return null;
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Preço',
                          prefix: Text('R\$ '),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+-]?([0-9]+([.][0-9]*)?)')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: mass,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira um volume/massa';
                          }
                          if (double.tryParse(value) == null)
                            return "Volume/massa inválido";
                          return null;
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Volume/Massa',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+-]?([0-9]+([.][0-9]*)?)')),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        style: const TextStyle(overflow: TextOverflow.clip),
                        items: list
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (String? value) {
                          // This is called when the user selects an item.
                          setState(() {
                            dropdownValue = value!;
                          });
                        },
                        hint: const Text("Un. Medida"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira uma unidade de medida';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Un. de medida',
                        ),
                        value: dropdownValue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState == null ||
              !_formKey.currentState!.validate()) return;
          Item item = Item(
            name: name.text,
            price: double.parse(price.text),
            mass: double.parse(mass.text),
            unit: Item.unitFromString(dropdownValue!),
          );
          db.put(item.id, item.toString());
          Navigator.pop(context);
        },
        tooltip: 'Increment',
        shape: const StadiumBorder(),
        child: const Icon(Icons.check),
      ),
    );
  }
}

class EditElement extends StatefulWidget {
  final Item item;
  final Box<dynamic> db;
  const EditElement({super.key, required this.item, required this.db});

  @override
  // ignore: no_logic_in_create_state
  State<EditElement> createState() => _EditElement(
        item: item,
        db: db,
      );
}

// ignore: must_be_immutable
class _EditElement extends State<EditElement> {
  String? dropdownValue;
  Item item;
  final Box<dynamic> db;
  _EditElement({required this.item, required this.db});

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Editar produto"),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: Text(
                    "Editar produto",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nome',
                        ),
                        initialValue: item.name,
                        keyboardType: TextInputType.text,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.singleLineFormatter,
                        ],
                        onChanged: (value) {
                          setState(() {
                            item.name = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Preço',
                          prefix: Text('R\$ '),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Insira o preço';
                          if (double.tryParse(value) == null)
                            return "Preço inválido";
                          return null;
                        },
                        initialValue: item.price.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+-]?([0-9]+([.][0-9]*)?)')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            item.price = double.parse(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 30,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Volume/Massa',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira um volume/massa';
                          }
                          if (double.tryParse(value) == null)
                            return "Volume/massa inválido";
                          return null;
                        },
                        initialValue: item.mass.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+-]?([0-9]+([.][0-9]*)?)')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            item.mass = double.parse(value);
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        style: const TextStyle(overflow: TextOverflow.clip),
                        items: list
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (String? value) {
                          // This is called when the user selects an item.
                          setState(() {
                            dropdownValue = value!;
                            item.unit = Item.unitFromString(value);
                          });
                        },
                        hint: const Text("Un. Medida"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira uma unidade de medida';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Un. de medida',
                        ),
                        value: dropdownValue ?? Item.unitToString(item.unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 50,
                ),
                Row(
                  children: [
                    const Expanded(flex: 2, child: SizedBox()),
                    ActionChip(
                      onPressed: () {
                        db.delete(item.id);
                        Navigator.pop(context);
                      },
                      label: const Text(
                        "Deletar",
                        style: TextStyle(fontSize: 16),
                      ),
                      avatar: const Icon(Icons.delete),
                    ),
                    const SizedBox(width: 25),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState == null ||
              !_formKey.currentState!.validate()) return;
          db.put(item.id, item.toString());
          Navigator.pop(context);
        },
        tooltip: 'Increment',
        shape: const StadiumBorder(),
        child: const Icon(Icons.check),
      ),
    );
  }
}

class Item {
  String id;
  String name;
  double price;
  double mass;
  Unit unit;

  Item({
    required this.name,
    required this.price,
    required this.unit,
    required this.mass,
    this.id = "",
  }) {
    if (id == "") id = const Uuid().v4();
  }

  @override
  String toString() {
    return "$id;$name;$price;$mass;$unit";
  }

  static Item fromString(String item) {
    var items = item.split(";");
    Unit u = Unit.values.firstWhere((e) => e.toString() == items[4]);

    return Item(
      id: items[0],
      name: items[1],
      price: double.parse(items[2]),
      mass: double.parse(items[3]),
      unit: u,
    );
  }

  String get readableUnit {
    switch (unit) {
      case Unit.G:
        return "g";
      case Unit.KG:
        return "Kg";
      case Unit.L:
        return "L";
      case Unit.ML:
        return "mL";
    }
  }

  double get pricePerUnit {
    return price / universalUnitMass;
  }

  int purchaseableAmount(double budget) {
    return (budget / price).floor();
  }

  String get readablePricePerUnit {
    return "R\$${pricePerUnit.toStringAsFixed(2)}/${unitToString(universalUnit)}";
  }

  String get readableGeneralInfo {
    return "R\$${price.toStringAsFixed(2)}/${universalUnitMass.toStringAsFixed(2)}${unitToString(universalUnit)}";
  }

  double get universalUnitMass {
    if (unit == Unit.KG || unit == Unit.L) return mass;
    return mass / 1000;
  }

  Unit get universalUnit {
    if (unit == Unit.KG || unit == Unit.L) return unit;
    return unit == Unit.G ? Unit.KG : Unit.L;
  }

  String readableSummary(double budget) {
    if (budget == 0) return "";
    int amount = purchaseableAmount(budget);
    if (amount == 0) return "";
    String unitString = unitToString(universalUnit);
    double resultingMass = universalUnitMass * amount;
    double resultingPrice = price * amount;
    return "${amount}un. * ${universalUnitMass.toStringAsFixed(2)}$unitString = ${resultingMass.toStringAsFixed(2)}$unitString por R\$${resultingPrice.toStringAsFixed(2)}";
  }

  double resultingMass(double budget) {
    return universalUnitMass * purchaseableAmount(budget);
  }

  static String unitToString(Unit unit) {
    switch (unit) {
      case Unit.KG:
        return "Kg";
      case Unit.G:
        return "g";
      case Unit.ML:
        return "mL";
      case Unit.L:
        return "L";
    }
  }

  static Unit unitFromString(String unit) {
    switch (unit.toLowerCase()) {
      case "kg":
        return Unit.KG;
      case "g":
        return Unit.G;
      case "l":
        return Unit.L;
      case "ml":
        return Unit.ML;
    }
    return Unit.KG;
  }
}

// ignore: constant_identifier_names
enum Unit { KG, G, L, ML }
